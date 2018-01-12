// LDA Topic Estimation using a distributed Markov Chain Monte Carlo
//approach that is similar to AD-LDA from Newman et. al., "Distributed
//Algorithms for Topic Models" Journal of Machine Learning Research 10
//(2009) 1801-1828.
IMPORT $ AS LDA;
IMPORT $.Types AS Types;
IMPORT Std.System.ThorLib;
Doc_assigned := Types.Doc_Assigned_MC;
Coll := Types.Collection_MC;
Freq := Types.MC_Freq;
Parms := Types.MC_Model_Parameters;
Nom_Map := Types.Model_Nom_Ord_Map;
emp := DATASET([], Types.Model_Topic);
Model_Topic := Types.Model_Topic_MC_Result;
TermValue := Types.TermValue;
/**
 * Topic estimation using Monte Carlo methods.
 *@param patameters model parameters
 *@param initial_estimate inital estimated model
 *@param stats collection statistics
 *@param docs the documents mapped to each model
 *@return Model Topic result (co-efficients per topic)
 */
EXPORT DATASET(Types.Model_Topic_MC_Result)
    Topic_Estimation_MC(DATASET(Types.MC_Model_Parameters) parameters,
                        DATASET(Types.Model_Topic) initial_estimate=emp,
                        DATASET(Types.Model_Collection_Stats) stats,
                        DATASET(Types.Model_Nom_Ord_Map) mno_map,
                        DATASET(Types.Doc_Mapped) docs) := FUNCTION
    // prepare the docs for sampling, including collection info
    mc_docs := LDA.prep_mc_docs(parameters, initial_estimate, stats,
                                mno_map, docs);
    //run thorough the burn-in period
    Doc_Assigned get_iter_count(Doc_Assigned doc,
                                Parms p, UNSIGNED2 pass) := TRANSFORM
      SELF.max_iterations := CHOOSE(pass,
                                    p.initial_iterations,
                                    p.max_doc_iterations);
      SELF.iteration := 0;
      SELF := doc;
    END;
    burnin_input := JOIN(mc_docs, parameters,
                        LEFT.model=RIGHT.model,
                        get_iter_count(LEFT, RIGHT, 1), LOOKUP);
    burned := LOOP(burnin_input, LEFT.max_iterations > LEFT.iteration,
                   LDA.sample_docs(ROWS(LEFT)));
    //run through the iterations
    sample_input := JOIN(burned, parameters,
                         LEFT.model=RIGHT.model,
                         get_iter_count(LEFT, RIGHT, 2), LOOKUP);
    sampled := LOOP(sample_input, LEFT.max_iterations>LEFT.iteration,
                    LDA.sample_docs(ROWS(LEFT)));
    // extract from collection, duplicated on every node
    collection_counts := PROJECT(sampled(NOT isDoc), Coll);
    Work_nw := RECORD
      Types.t_model_id model;
      Types.t_topic topic;
      Types.t_ordinal ordinal;
      INTEGER8 freq;
    END;
    Work_nw extract_nw(Coll c, Freq f, UNSIGNED8 pos) := TRANSFORM
      ordinal := ((pos-1)/c.num_topics)+1;
      topic := ((pos-1)%c.num_topics) + 1;
      topic_node := topic % ThorLib.nodes() = ThorLib.node();
      SELF.model := c.model;
      SELF.ordinal := ordinal;
      SELF.topic := IF(topic_node, topic, SKIP);
      SELF.freq := f.freq;
    END;
    nw_recs := NORMALIZE(collection_counts, LEFT.nw,
                         extract_nw(LEFT, RIGHT, COUNTER));
    Work_nwsum := RECORD
      Types.t_model_id model;
      Types.t_topic topic;
      UNSIGNED4 num_topics;
      UNSIGNED4 uniq_words;
      INTEGER freq;
    END;
    Work_nwsum extract_nwsum(Coll c, Freq f, UNSIGNED8 pos) := TRANSFORM
      topic := pos;
      topic_node := topic % ThorLib.nodes() = ThorLib.node();
      SELF.model := c.model;
      SELF.num_topics := c.num_topics;
      SELF.uniq_words := c.uniq_words;
      SELF.topic := IF(topic_node, topic, SKIP);
      SELF.freq := f.freq;
    END;
    nwsum_recs := NORMALIZE(collection_counts, LEFT.nwsum,
                            extract_nwsum(LEFT, RIGHT, COUNTER));
    // pick up alpha and beta
    With_ab := RECORD(Work_nwsum)
      REAL8 alpha;
      REAL8 beta;
    END;
    With_ab append_ab(Work_nwsum n, Parms p) := TRANSFORM
      SELF.alpha := p.initial_alpha;
      SELF.beta := p.initial_beta;
      SELF := n;
    END;
    nwsum_with_ab := JOIN(nwsum_recs, parameters,
                          LEFT.model=RIGHT.model,
                          append_ab(LEFT,RIGHT), LOOKUP);
    // Calculate term weights
    Work_Phi := RECORD
      Types.t_model_id model;
      Types.t_topic topic;
      Types.t_ordinal ordinal;
      Types.t_nominal nominal;
      REAL8 v;
    END;
    Work_Phi calc_phi(Work_nw nw, with_ab nwsum) := TRANSFORM
      SELF.v := (nw.freq + nwsum.beta)
              / (nwsum.freq + nwsum.uniq_words*nwsum.beta);
      SELF.nominal := 0;  // need to get this next
      SELF := nw;
    END;
    ord_weights := JOIN(nw_recs, nwsum_with_ab,
                        LEFT.model=RIGHT.model
                        AND LEFT.topic=RIGHT.topic,
                        calc_phi(LEFT, RIGHT), LOCAL, LOOKUP);
    // pick up nominal
    Work_Phi get_nominal(Work_Phi phi, Nom_Map nm) := TRANSFORM
      SELF.nominal := nm.nominal;
      SELF := phi;
    END;
    nom_weights := JOIN(ord_weights, mno_map,
                        LEFT.model=RIGHT.model
                        AND LEFT.ordinal=RIGHT.ordinal,
                        get_nominal(LEFT,RIGHT), LOOKUP);
    // Moke model Topic records
    Model_Topic make_base(With_ab nwsum) := TRANSFORM
      SELF.model := nwsum.model;
      SELF.alpha := nwsum.alpha;
      SELF.beta := nwsum.beta;
      SELF.topic := nwsum.topic;
      SELF.unique_words := nwsum.uniq_words;
      SELF.num_topics := nwsum.num_topics;
      SELF := [];
    END;
    base_result := PROJECT(nwsum_with_ab, make_base(LEFT));
    Model_Topic add_weights(Model_Topic mt,
                            DATASET(Work_phi) phis) := TRANSFORM
      SELF.weights := PROJECT(SORT(phis, nominal), TermValue);
      SELF := mt;
    END;
    rslt := DENORMALIZE(base_result, nom_weights,
                        LEFT.model=RIGHT.model
                        AND LEFT.topic=RIGHT.topic,
                        GROUP, add_weights(LEFT, ROWS(RIGHT)), LOCAL);
    RETURN rslt;
END;