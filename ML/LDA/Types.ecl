// Types for LDA
//WARNING!!!! Do not change t_topic, Topic_Values, TermValues, TermFreq
//without making corresponding changes to typedef definitions in C++ attributes
EXPORT Types := MODULE
  // External definitions
  EXPORT t_topic := UNSIGNED4;      // tens to hundreds of thousands of topics
  EXPORT t_model_id := UNSIGNED2;   // model identifier, expect hundreds
  EXPORT t_nominal := UNSIGNED8;    // allow use of hash value for nominal
  EXPORT t_ordinal := UNSIGNED4;    // ordinal for compact representation
  EXPORT t_record_id := UNSIGNED4;
  EXPORT Term_Dict := RECORD
    t_nominal nominal;
    UNICODE term;
  END;
  EXPORT Model_Term_Dict_Ord := RECORD(Term_Dict)
    t_model_id model;
    t_ordinal ordinal;
  END;
  EXPORT Model_Nom_Ord_Map := RECORD
    t_model_id model;
    t_ordinal ordinal;
    t_nominal nominal;
    UNSIGNED8 freq;
  END;
  EXPORT TermValue := RECORD
    t_nominal nominal;              // nominal for the term
    REAL8 v;                        // value
  END;
  EXPORT OnlyValue := RECORD
    REAL8 v;
  END;
  EXPORT TermFreq := RECORD
    t_nominal nominal;              // nominal for the term
    UNSIGNED4 v;                    // number of occurrences in this record
  END;
  EXPORT Topic_TermValues := RECORD
    t_topic topic;
    EMBEDDED DATASET(TermValue) tvs;
  END;
  EXPORT Topic_Values := RECORD
    t_topic topic;
    EMBEDDED DATASET(OnlyValue) vs;
  END;
  EXPORT Topic_Value := RECORD
    t_topic topic;
    REAL8 v;
  END;
  EXPORT Topic_Value_DataSet := EMBEDDED DATASET(Topic_Value);
  EXPORT Topic_Values_DataSet := EMBEDDED DATASET(Topic_Values);
  EXPORT TermFreq_DataSet := EMBEDDED DATASET(TermFreq);
  EXPORT TermValue_DataSet := EMBEDDED DATASET(TermValue);
  EXPORT OnlyValue_DataSet := EMBEDDED DATASET(OnlyValue);
  EXPORT Model_Identifier := RECORD
    t_model_id model;               // model identifier
  END;
  EXPORT Model_Topic := RECORD(Model_Identifier)
    t_topic topic;                  // topic nominal
    REAL8 alpha;                    // alpha for all topics
    DATASET(TermValue) weights;     // nominal and coefficient pairs
  END;
  EXPORT Model_Seed_Info := RECORD(Model_Identifier)
    UNSIGNED4 num_topics;           // number of topics to model
    UNSIGNED2 num_docs;             // number of documents for each topic
  END;
  EXPORT Model_Parameters := RECORD(Model_Identifier)
    UNSIGNED4 num_topics;           // number of topics to model
    REAL8 initial_alpha;            // initial alpha value
    REAL8 initial_beta;             // initial beta value
  END;
  EXPORT EM_Model_Parameters := RECORD(Model_Parameters)
    UNSIGNED2 max_beta_iterations;  // EM convergence limit
    UNSIGNED2 max_doc_iterations;   // variational convergence limit
    REAL8 alpha;                    // initial alpha value;
    REAL8 doc_epsilon;              // maximum change for convergence
    REAL8 beta_epsilon;             // maximum change for convergence
    BOOLEAN estimate_alpha;         // evolve the value of alpha
  END;
  EXPORT MC_Model_Parameters := RECORD(Model_Parameters)
    UNSIGNED4 initial_iterations;   // initial burn-in period
    UNSIGNED4 max_doc_iterations;   // maximum times to pass through the docs
    UNSIGNED4 step_iterations;      // iterations between checking likelihood
    REAL8 epsilon;                  // threshold change in log likelihood
  END;
  EXPORT Model_Collection_Stats := RECORD
    t_model_id model;               // model identifier
    UNSIGNED4 docs;                 // number of documents
    UNSIGNED4 unique_words;         // number of unique words or terms
    UNSIGNED4 doc_min_words;        // minimum words of a document
    UNSIGNED4 doc_max_words;        // maximum words on a document
    UNSIGNED8 words;                // total words or terms in collection
    UNSIGNED8 low_nominal;          // lowest nominal value
    UNSIGNED8 high_nominal;         // highest nominal value
    REAL8 doc_ave_words;            // average words on a document
  END;
  EXPORT Document := RECORD
    t_record_id rid;
    DATASET(TermFreq) word_counts;
  END;
  EXPORT Seed_Document := RECORD(Document)
    t_model_id model;
    t_topic topic;
  END;
  EXPORT Doc_Mapped := RECORD(Document)
    SET OF t_model_id models;
  END;
  EXPORT Document_Scored := RECORD
    t_model_id model;
    t_record_id rid;
    REAL8 likelihood;               // log likelihood
    DATASET(Topic_Value) topics;
  END;
  EXPORT Term_Ordinal := RECORD
    t_ordinal ordinal;
  END;
  EXPORT Likelihood_Hist := RECORD
    UNSIGNED2 iteration;
    REAL8 likelihood;
  END;
  EXPORT Model_Topic_EM_Result := RECORD(Model_Topic)
    UNSIGNED4 docs;                 // same for all topics for model
    UNSIGNED4 unique_words;         // same for all topics for model
    UNSIGNED4 num_topics;           // same for all topics for model
    REAL8 likelihood;               // current likelihood value
    REAL8 likelihood_change;        // rate of change from last
    REAL8 beta_epsilon;             // convergence threshold for change rate
    REAL8 doc_epsilon;              // convergence threshold for change rate
    UNSIGNED2 last_alpha_iter;      // number of iterations for last alpha est
    UNSIGNED2 EM_iterations;        // number of iterations needed
    UNSIGNED2 max_beta_iterations;  // max number of beta iterations allowed
    UNSIGNED2 max_doc_iterations;   // max number of E step iterations allowed
    UNSIGNED2 last_doc_iterations;  // ave doc iterations taken last iteration
    UNSIGNED2 last_doc_max_iter;    // max doc iterations taken last iteration
    UNSIGNED2 last_doc_min_iter;    // min doc iterations taken last iteration
    UNSIGNED4 last_docs_converged;  // number converged last iteration
    REAL8 last_average_change;      // average change in last iteration
    REAL8 last_min_change;          // min change in last iteration
    REAL8 last_max_change;          // max change in last iteration
    REAL8 last_min_likelihood;      // min doc likelihood from last iteration
    REAL8 last_max_likelihood;      // max doc likelihood from last iteration
    REAL8 last_alpha_df;            // last df value fro the alpha estimate
    REAL8 last_init_alpha;          // last value for the initial
    BOOLEAN estimate_alpha;         // evolve the value of alpha
    DATASET(Likelihood_Hist) hist;  // log likelihood values from EM
    DATASET(TermValue) logBetas;    // log of what will become the weight
  END;
  EXPORT Model_Topic_MC_Result := RECORD(Model_Topic)
    UNSIGNED4 docs;                 // same for all topics for model
    UNSIGNED4 unique_words;         // same for all topics for model
    UNSIGNED4 num_topics;           // same for all topics for model
    REAL8 beta;                     // beta for all topics
    REAL8 likelihood;               // current likelihood value
    REAL8 likelihood_change;        // rate of change from last
    UNSIGNED4 iterations;
    DATASET(Likelihood_Hist) hist;  // log likelihood values from sample
  END;
  EXPORT Topic_Term := RECORD
    t_nominal nominal;              // term nominal
    REAL8 v;                        // term beta or weight for the topic
    UNICODE term;                   // text of the term
  END;
  EXPORT Model_Topic_Top_Terms := RECORD
    t_model_id model;               // model identifier
    t_topic topic;                  // topic identifier
    DATASET(Topic_Term) terms;      // list of top terms for this topic
  END;
  // Internal common definitions
  EXPORT MC_Term_Topic := RECORD
    t_ordinal ordinal;
    t_topic topic;
  END;
  EXPORT MC_Freq := RECORD
    INTEGER8 freq;    // index by topic - 1
  END;
  EXPORT MC_Topic_Freq := RECORD
    t_topic topic;
    INTEGER8 freq;
  END;
  EXPORT MC_Term_Topic_Map := RECORD
    UNSIGNED4 num_topics;     // term ordinal implied by position
    UNSIGNED4 list_pos;       // index into MC_Topic_Freq array
  END;
  EXPORT MC_Term_Topic_Freq := RECORD
    t_ordinal ordinal;
    t_topic topic;
    INTEGER8 freq;
  END;
  EXPORT Collection_Work_Handle := UNSIGNED8;
  EXPORT Doc_Assigned_MC := RECORD
    t_record_id rid;
    t_model_id model;
    UNSIGNED4 max_iterations;
    UNSIGNED4 iteration;
    UNSIGNED4 uniq_words;
    UNSIGNED4 doc_words;
    UNSIGNED4 num_topics;
    UNSIGNED4 doc_topics;
    t_ordinal split;
    REAL8 alpha;
    REAL8 beta;
    BOOLEAN isDoc;    // document or collection data
    BOOLEAN isFirst;
    Collection_Work_Handle hand;
    EMBEDDED DATASET(MC_Term_Topic) z;
    EMBEDDED DATASET(MC_Freq) nd;
    EMBEDDED DATASET(MC_Freq) nwsum;
    EMBEDDED DATASET(MC_Freq) nw;
    EMBEDDED DATASET(MC_Term_Topic_Map) nwmap;
    EMBEDDED DATASET(MC_Topic_Freq) nwfreq;
  END;
  EXPORT Collection_MC := RECORD
    t_model_id model;
    t_ordinal split;
    UNSIGNED4 num_topics;
    UNSIGNED4 uniq_words;
    EMBEDDED DATASET(MC_Freq) nwsum;
    EMBEDDED DATASET(MC_Freq) nw;
    EMBEDDED DATASET(MC_Term_Topic_Map) nwmap;
    EMBEDDED DATASET(MC_Topic_Freq) nwfreq;
  END;
  EXPORT Doc_Assigned_EM := RECORD
    t_record_id rid;
    t_model_id model;
    UNSIGNED4 num_topics;
    UNSIGNED4 num_ranges;
    UNSIGNED4 per_range;
    TermFreq_DataSet word_counts;
  END;
  EXPORT Doc_Topics_EM := RECORD
    t_Record_id rid;                // doc identifier
    t_model_id model;               // model identifier
    t_topic topic_low;              // low topic identifier in range
    t_topic topic_high;             // high topic identifier in range
    UNSIGNED4 topic_range;          // range ordinal, 1 to num_ranges
    UNSIGNED4 num_ranges;           // number of topic ranges
    UNSIGNED4 num_topics;           // number of topics for this model
    UNSIGNED2 max_doc_iterations;   // doc iterations allowed
    UNSIGNED2 doc_iterations;       // doc iterations taken this doc
    REAL8 likelihood;               // log likelihood
    REAL8 alpha;                    // topic alpha
    REAL8 likelihood_change;        // rate of change in likelihood
    REAL8 doc_epsilon;              // convergence threshold for change rate
    Topic_Value_DataSet t_gammas;   // topic gammas
    Topic_Value_DataSet t_digammas; // topic digamma values
    TermFreq_DataSet word_counts;   // nominal and term occurrence count pairs
    Topic_Values_DataSet t_phis;    // topic and array of phi values
    Topic_Values_DataSet t_logBetas;// topic and array of log beta values
    BOOLEAN estimate_alpha;         // evolve the value of alpha
  END;
  EXPORT Alpha_Estimate := RECORD
    t_model_id model;
    UNSIGNED4 num_topics;
    UNSIGNED4 docs;
    UNSIGNED2 iter;
    REAL8 init_alpha;
    REAL8 alpha;
    REAL8 log_alpha;
    REAL8 suff_stat;
    REAL8 last_df;
  END;
  EXPORT Work_MC_Model_Parm := RECORD(MC_Model_Parameters)
    UNSIGNED8 words;    // words in the collection
    UNSIGNED4 docs;     // documents
    UNSIGNED4 uniq_words;
    t_ordinal split;
  END;
  EXPORT Collection_Work := RECORD
    t_model_id model;
    UNSIGNED4 num_topics;
    UNSIGNED4 uniq_words;
    t_ordinal split;
    UNSIGNED4 pairs;
    EMBEDDED DATASET(MC_Freq, COUNT(SELF.num_topics)) nwsum;
    EMBEDDED DATASET(MC_Freq, COUNT(SELF.split*self.num_topics)) nw;
    EMBEDDED DATASET(MC_Term_Topic_Map,
                     COUNT(SELF.uniq_words-SELF.split)) nwmap;
    EMBEDDED DATASET(MC_Topic_Freq, COUNT(SELF.pairs)) nwfreq;
  END;
  EXPORT Sampling_Result := RECORD
    t_model_id model;
    UNSIGNED4 doc_words;
    UNSIGNED4 num_topics;
    REAL8 log_likelihood;
    Collection_Work_Handle hand;
    EMBEDDED DATASET(MC_Freq, COUNT(SELF.num_topics)) nd;
    EMBEDDED DATASET(MC_Term_Topic, COUNT(SELF.doc_words)) z;
  END;

END;