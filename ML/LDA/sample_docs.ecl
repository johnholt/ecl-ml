// Sample documents for MCMC topic estimation
//The LDA approach to topic modeling is to infer the distribution parameters.
//The probability model is each word occurrence is a random draw from a topic
// specific word distribution, and that there are a random set of topics
// associated with each document.
//The global collection information (the matrix of word by topic counts)
// is held on each node as a pseudo-document in the document record set.
//The documents are processed by re-sampling the topic assignments.  The
// local version of the changed global counts are then compared against
// the original global state to determine the set of local changes.
//The local changes are then replicated and distributed to each node.  Each
// node applied the changes from the other nodes to their updated state
// to individually arrive at a local copy of the new global state.
IMPORT $ AS LDA;
IMPORT $.Types AS Types;
IMPORT Std.System.ThorLib AS ThorLib;
// Aliases for convenience
resample := LDA.resample_topics;
Sampling_Result := Types.Sampling_Result;
Doc_Assigned := Types.Doc_Assigned_MC;
Coll_MC := Types.Collection_MC;

EXPORT DATASET(Types.Doc_Assigned_MC)
    sample_docs(DATASET(Types.Doc_Assigned_MC) docs) := FUNCTION
  // split collection data
  Coll_MC getCollection(Types.Doc_Assigned_MC d) := TRANSFORM
    SELF := d;
  END;
  cinfo_begin := PROJECT(docs(NOT isDoc), getCollection(LEFT));
  //Extend Docs
  Ex_Doc := RECORD(Types.Doc_Assigned_MC)
    BOOLEAN missing_coll;
    BOOLEAN hadFirst;
  END;
  Ex_Doc extendDoc(Types.Doc_Assigned_MC d) := TRANSFORM
    SELF.missing_coll := FALSE;
    SELF.hadFirst := FALSE;
    SELF := d;
  END;
  init_mark := PROJECT(docs, extendDoc(LEFT));
  Ex_Doc markFirst(Ex_Doc prev, Ex_Doc curr) := TRANSFORM
    SELF.missing_coll := prev.model<>curr.model AND prev.isDoc;
    SELF.hadFirst := (prev.model<>curr.model AND curr.isFirst)
                  OR (prev.model=curr.model AND prev.hadFirst);
    SELF := curr;
  END;
  marked := ITERATE(init_mark, markFirst(LEFT, RIGHT), LOCAL);
  checked := ASSERT(marked,
                ASSERT(hadFirst, 'First Doc Not Marked', FAIL),
                ASSERT(NOT missing_coll, 'Collection missing', FAIL));
  Ex_Doc extendDocs(Ex_Doc doc, Coll_MC c) := TRANSFORM
    SELF.nwsum := IF(doc.isFirst, c.nwsum, doc.nwsum);
    SELF.nw := IF(doc.isFirst, c.nw, doc.nw);
    SELF.nwmap := IF(doc.isFirst, c.nwmap, doc.nwmap);
    SELF.nwfreq := IF(doc.isFirst, c.nwfreq, doc.nwfreq);
    SELF.hand := 0;
    SELF := doc;
  END;
  extended := JOIN(checked, cinfo_begin, LEFT.model=RIGHT.model,
                   extendDocs(LEFT, RIGHT), LOCAL, LOOKUP);
  // process documents by model
  Ex_Doc iter(Ex_Doc prev, Ex_Doc curr) := TRANSFORM
    doc := LDA.resample_topics(curr.model, curr.rid, prev.hand,
                     curr.isDoc, curr.doc_words,
                     curr.num_topics, curr.alpha, curr.beta,
                     curr.nd, curr.z, curr.uniq_words, curr.split,
                     COUNT(curr.nwfreq), curr.nwsum,
                     curr.nw, curr.nwmap, curr.nwfreq);
    col := LDA.extract_resample_counts(doc.model, prev.hand,
                     curr.isDoc, ~curr.isDoc);
    SELF.z := IF(curr.isDoc, doc.z);
    SELF.nd := IF(curr.isDoc, doc.nd);
    SELF.nwsum := IF(NOT curr.isDoc, col.nwsum);
    SELF.nw := IF(NOT curr.isDoc, col.nw);
    SELF.nwmap := IF(NOT curr.isDoc, col.nwmap);
    SELF.nwfreq := IF(NOT curr.isDoc, col.nwfreq);
    SELF.hand := IF(curr.isDoc, doc.hand, 0);
    SELF := curr;
  END;
  sampled_ex := ITERATE(extended, iter(LEFT, RIGHT), LOCAL);
  Ex_Doc trim_doc(Ex_Doc w) := TRANSFORM
    SELF.z := IF(w.isDoc, w.z);
    SELF.nd := IF(w.isDoc, w.nd);
    SELF.nwsum := IF(NOT w.isDoc, w.nwsum);
    SELF.nw := IF(NOT w.isDoc, w.nw);
    SELF.nwmap := IF(NOT w.isDoc, w.nwmap);
    SELF.nwfreq := IF(NOT w.isDoc, w.nwfreq);
    SELF := w;
  END;
  sampled := PROJECT(sampled_ex, trim_doc(LEFT));
  //Determine the change
  local_cinfo_end := PROJECT(sampled(NOT isDoc), getCollection(LEFT));
  Work_Coll_MC := RECORD(Coll_MC)
    UNSIGNED2 this_node;
    UNSIGNED2 target_node;
  END;
  Work_Coll_MC diff(Coll_MC bgn_rec, Coll_MC end_rec) := TRANSFORM
    delta := LDA.diff_counts(end_rec.model, end_rec.num_topics,
                            end_rec.uniq_words, end_rec.split,
                            COUNT(end_rec.nwfreq),
                            end_rec.nwsum, end_rec.nw,
                            end_rec.nwmap, end_rec.nwfreq,
                            COUNT(bgn_rec.nwfreq),
                            bgn_rec.nwsum, bgn_rec.nw,
                            bgn_rec.nwmap, bgn_rec.nwfreq);
    SELF.this_node := ThorLib.node();
    SELF.target_node := 0;
    SELF := delta;
  END;
  cinfo_diff := JOIN(cinfo_begin, local_cinfo_end,
                     LEFT.model=RIGHT.model,
                     diff(LEFT, RIGHT), LOCAL);
  //Distribute the change
  Work_Coll_MC replicate(Work_Coll_MC b, UNSIGNED c) := TRANSFORM
    SELF.target_node := IF(c-1<b.this_node, c-1, c);
    SELF := b;
  END;
  cinfo_diff_copies := NORMALIZE(cinfo_diff, ThorLib.Nodes()-1,
                                 replicate(LEFT, COUNTER));
  dist_diff := DISTRIBUTE(cinfo_diff_copies, target_node);
  //Apply difference from other nodes to get composite end point
  Coll_MC apply_diff(Coll_MC b, Work_Coll_MC d) := TRANSFORM
    accum := LDA.mrg_counts(b.model, b.num_topics,
                            b.uniq_words, b.split,
                            COUNT(b.nwfreq),
                            b.nwsum, b.nw, b.nwmap, b.nwfreq,
                            COUNT(d.nwfreq),
                            d.nwsum, d.nw, d.nwmap, d.nwfreq);
    SELF := accum;
    SELF := b;
  END;
  cinfo_end := DENORMALIZE(local_cinfo_end, dist_diff,
                           LEFT.model=RIGHT.model,
                           apply_diff(LEFT, RIGHT), LOCAL);
  //update dummy document record
  Doc_Assigned update(Doc_Assigned doc, Coll_MC coll) := TRANSFORM
    SELF.nwsum := IF(NOT doc.isDoc, coll.nwsum);
    SELF.nw := IF(NOT doc.isDoc, coll.nw);
    SELF.nwmap := IF(NOT doc.isDoc, coll.nwmap);
    SELF.nwfreq := IF(NOT doc.isDoc, coll.nwfreq);
    SELF.z := IF(doc.isDoc, doc.z);
    SELF.nd := IF(doc.isDoc, doc.nd);
    SELF.iteration := doc.iteration + 1;
    SELF := doc;
  END;
  rslt := JOIN(sampled, cinfo_end, LEFT.model=RIGHT.model,
               update(LEFT, RIGHT), LOCAL, LOOKUP);
  RETURN rslt;
END;