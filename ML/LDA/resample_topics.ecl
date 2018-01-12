//Draw new topics for each word in the document.  Update
// in-memory object for counters.  High frequency terms
// term-topic matrix of counts is dense.  The lower frequency
// term-topic counts are held in a sparse matrix.  The arguments
// include a handle to the object and a flag to indicate whether
// the call is being made with an actual document.  If the
// handle is zero, then this is the first document so an object
// must be created and initialized.
IMPORT $ AS LDA;
IMPORT $.Types AS Types;
//
DATA resample(Types.t_model_id model, UNSIGNED6 rid,
              Types.Collection_Work_Handle hand, BOOLEAN isDoc,
              UNSIGNED4 doc_words, UNSIGNED4 num_topics,
              REAL8 alpha, REAL8 beta,
              EMBEDDED DATASET(Types.MC_Freq) nd,
              EMBEDDED DATASET(Types.MC_Term_Topic) z,
              UNSIGNED4 uniq_words, Types.t_ordinal split, UNSIGNED4 pairs,
              EMBEDDED DATASET(Types.MC_Freq) nwsum,
              EMBEDDED DATASET(Types.MC_Freq) nw,
              EMBEDDED DATASET(Types.MC_Term_Topic_Map) nwmap,
              EMBEDDED DATASET(Types.MC_Topic_Freq) nwfreq) := BEGINC++
//  #include <random>
  ECLRTL_API unsigned rtlDisplay(unsigned len, const char * src);
  #include <stdio.h>
  #include <cstdlib>
  #include <algorithm>
  #include <ctime>
  #ifndef LDA_MC_SAMPLING_RESULT
  #define LDA_MC_SAMPLING_RESULT
  struct __attribute__ ((__packed__)) LDA_MC_Sampling_Result {
    uint16_t model;
    uint32_t doc_words;
    uint32_t num_topics;
    double log_likelihood;
    uint64_t handle;
    //nd[num_topics], z[doc_words]
  };
  #endif
  #ifndef LDA_MC_FREQ
  #define LDA_MC_FREQ
  struct __attribute__ ((__packed__)) LDA_MC_Freq {
    int64_t freq;
  };
  #endif
  #ifndef LDA_MC_TERM_TOPIC
  #define LDA_MC_TERM_TOPIC
  struct __attribute__ ((__packed__)) LDA_MC_Term_Topic {
    uint32_t ordinal;
    uint32_t topic;
  };
  #endif
  #ifndef LDA_MC_TOPIC_FREQ
  #define LDA_MC_TOPIC_FREQ
  struct __attribute__ ((__packed__)) LDA_MC_Topic_Freq {
    uint32_t topic;
    int64_t freq;
  };
  #endif
  #ifndef LDA_MC_SAMPLING_OBJECT
  #define LDA_MC_SAMPLING_OBJECT
  struct __attribute__ ((__packed__)) LDA_MC_Sampling_Object {
    uint16_t model;
    uint32_t num_topics;
    uint32_t uniq_words;
    uint32_t split;
    int64_t *nwsum;  //[num_topics]
    int64_t *nw;     //[split*num_topics]
    uint32_t *nw_c;   //[uniq_words-split], number of topics
    LDA_MC_Topic_Freq **nw_tf;   //[uniq_words-split][freq]
  };
  #endif
  #ifndef LDA_MC_TERM_TOPIC_MAP
  #define LDA_MC_TERM_TOPIC_MAP
  struct __attribute__ ((__packed__)) LDA_MC_Term_Topic_Map {
    uint32_t num_topics; //
    uint32_t list_pos;   // zero based
  };
  #endif
  // #DEFINE LDA_MCMC_LOGGING
  #body
  // message buffer
  char buffer[200];
  // Empty reply if not a document
  if (!isdoc) {
    __lenResult = sizeof(LDA_MC_Sampling_Result);
    __result = rtlMalloc(__lenResult);
    ((LDA_MC_Sampling_Result*) __result)->model = model;
    ((LDA_MC_Sampling_Result*) __result)->handle = hand;
    ((LDA_MC_Sampling_Result*) __result)->num_topics = 0;
    ((LDA_MC_Sampling_Result*) __result)->doc_words= 0;
    ((LDA_MC_Sampling_Result*) __result)->log_likelihood = 0.0;
    return;
  }
  // Establish sampling object as needed
  LDA_MC_Sampling_Object *so;
  if (hand!=0) so = (LDA_MC_Sampling_Object*) hand;
  else {
    // collection word counts assigned to topic
    const LDA_MC_Freq* in_nwsum = (LDA_MC_Freq*) nwsum;
    if(lenNwsum/sizeof(LDA_MC_Freq)!=num_topics) rtlFail(0,"nwsum size");
    // ordinals 1 to split, topic count array
    const LDA_MC_Freq* in_nw = (LDA_MC_Freq*) nw;
    if(lenNw/sizeof(LDA_MC_Freq)!=num_topics*split) rtlFail(0,"nw size");
    // ordinals split+1 to uniq_words, head of topic list
    const LDA_MC_Term_Topic_Map* in_nwmap = (LDA_MC_Term_Topic_Map*)nwmap;
    if(lenNwmap/sizeof(LDA_MC_Term_Topic_Map)!=uniq_words-split) {
      sprintf(buffer, "nwmap %d,uw=%d,s=%d",lenNwmap,uniq_words,split);
      rtlFail(0,buffer);
    }
    // ordinals split+1 to uniq_words topic list
    const LDA_MC_Topic_Freq* in_nwfreq = (LDA_MC_Topic_Freq*) nwfreq;
    if(lenNwfreq/sizeof(LDA_MC_Topic_Freq)!=pairs) rtlFail(0,"nwfreq sz");
    //Done with input checks.
    const uint32_t rare_words = uniq_words - split;
    // Allocate Objects
    so = (LDA_MC_Sampling_Object*) rtlMalloc(sizeof(LDA_MC_Sampling_Object));
    // initialize counting object
    so->nwsum = (int64_t*) rtlMalloc(num_topics*sizeof(int64_t));
    so->nw = (int64_t*) rtlMalloc(num_topics*split*sizeof(int64_t));
    so->nw_c = (uint32_t*) rtlMalloc(rare_words*sizeof(uint32_t));
    so->nw_tf = (LDA_MC_Topic_Freq**)
              rtlMalloc(rare_words*sizeof(LDA_MC_Topic_Freq*));
    so->model = model;
    so->num_topics = num_topics;
    so->uniq_words = uniq_words;
    so->split = split;
    // nwsum is count of all words by topic
    for (size32_t i=0; i< num_topics; i++) {
      so->nwsum[i] = in_nwsum[i].freq;
    }
    // nw is dense array of topic by word for common words
    for (size32_t i=0; i<num_topics*split; i++) {
      so->nw[i] = in_nw[i].freq;
    }
    // now we need to work with sparse array of topic by word
    // for rare words.  Cannot just copy the input array because
    // the resampling can change the topic assignements for each
    // word occurrence, which in turn will change the shape of
    // the sparse array.
    for (size32_t word = 0; word<rare_words; word++) {
      uint32_t pos = in_nwmap[word].list_pos;
      int64_t freq = 0;
      // first determine frequency for the rare word
      for (uint32_t i=0; i<in_nwmap[word].num_topics; i++) {
        freq += abs(in_nwfreq[pos].freq); //make positive
        pos++;
      }
      // allocate space for each occurrence to have a topic assigned
      // this run will produce different topic assignements for at least
      // some of the words, so we need space of all possible counts
      freq = std::min(freq, (int64_t)num_topics); //space for each topic
      so->nw_tf[word] = (LDA_MC_Topic_Freq*)
                      rtlMalloc(freq*sizeof(LDA_MC_Topic_Freq));
      pos = in_nwmap[word].list_pos;
      for (uint32_t i=0; i< in_nwmap[word].num_topics; i++) {
        so->nw_tf[word][i].topic = in_nwfreq[pos].topic;
        so->nw_tf[word][i].freq = in_nwfreq[pos].freq;
        pos++;
      }
      so->nw_c[word] = in_nwmap[word].num_topics;
    }
    // Log the allocation of the object
    #ifdef LDA_MCMC_LOGGING
    sprintf(buffer, "****** Allocated counting object, RID %lld, hand %p",
             rid, so);
    rtlDisplay(strlen(buffer), buffer);
    #endif
  }
  // Check the object
  if(so->model!=model) rtlFail(0, "Corrupt object, model mismatch");
  if(so->uniq_words<so->split) rtlFail(0, "Corrupt object, bad split");
  if(so->num_topics!=num_topics) rtlFail(0, "Corrupt object, topics");
  // topic assignments for this document
  const LDA_MC_Freq* in_nd = (LDA_MC_Freq*) nd;
  if(lenNd/sizeof(LDA_MC_Freq)!=num_topics) rtlFail(0,"nd size");
  // doc words with topics assigned
  const LDA_MC_Term_Topic* in_z = (LDA_MC_Term_Topic*) z;
  if(lenZ/sizeof(LDA_MC_Term_Topic)!=doc_words) rtlFail(0,"z size");
  //Done with input checks.
  // Allocate return
  __lenResult = sizeof(LDA_MC_Sampling_Result)
              + num_topics*sizeof(LDA_MC_Freq)           // nd
              + doc_words*sizeof(LDA_MC_Term_Topic);     // z
  __result = rtlMalloc(__lenResult);
  // Initialize outputs except for newmap and nwfreq
  size_t nd_offset = sizeof(LDA_MC_Sampling_Result);
  size_t z_offset = nd_offset + num_topics*sizeof(LDA_MC_Freq);
  LDA_MC_Sampling_Result* rslt = (LDA_MC_Sampling_Result*) __result;
  rslt->model = model;
  rslt->doc_words = doc_words;
  rslt->num_topics = num_topics;
  rslt->handle = (uint64_t) so;
  rslt->log_likelihood = 0.0;
  LDA_MC_Freq* out_nd = (LDA_MC_Freq*)(((uint8_t*)__result)+nd_offset);
  for (size32_t i=0; i<num_topics; i++) out_nd[i].freq = in_nd[i].freq;
  LDA_MC_Term_Topic* out_z = (LDA_MC_Term_Topic*)(((uint8_t*)__result)+z_offset);
  for (size32_t i=0; i<doc_words; i++) {
    out_z[i].ordinal = in_z[i].ordinal;
    out_z[i].topic = in_z[i].topic;
  }
  //
  // need temporary work for sampling and counting current word
  //  std::random_device rd;
  //  std::mt19937 gen(rd);
  //  std::uniform_real_distribution<> udis(0.0, 1.0);
  std::srand(std::time(0));
  const double denom = 1.0/RAND_MAX;
  double* p = (double*)rtlMalloc(sizeof(double)*num_topics);
  int64_t* work_nw = (int64_t*) rtlMalloc(sizeof(int64_t)*num_topics);
  for(size32_t i=0; i<num_topics; i++) work_nw[i]=0;
  // Loop through the words and draw sample topic.  Words are in
  //ordinal sequence.
  uint32_t curr_word_ord = out_z[0].ordinal;  //prime for previous track
  for(size32_t word=0; word<doc_words; word++) {
    uint32_t old_topic = out_z[word].topic;
    uint32_t prev_word_ord = curr_word_ord;
    curr_word_ord = out_z[word].ordinal;
    so->nwsum[old_topic-1]--;
    out_nd[old_topic-1].freq--;
    if (curr_word_ord<=so->split) { // a high freq word
      size32_t pos = ((curr_word_ord-1)*num_topics) + old_topic-1;
      so->nw[pos]--;
    } else { // a low freq word, sparse vectors
      //copy previously counted and now completed if present
      if(prev_word_ord>so->split && curr_word_ord>prev_word_ord) {
        int nz_entries = 0;
        for (size32_t i=0; i<num_topics; i++) if(work_nw[i]>0) {
          nz_entries++;
        }
        so->nw_c[prev_word_ord-so->split-1] = nz_entries;
        uint32_t next_pos = 0;
        for(size32_t i=0; i<num_topics; i++) {
          if (work_nw[i]>0) {
            so->nw_tf[prev_word_ord-so->split-1][next_pos].topic = i+1;
            so->nw_tf[prev_word_ord-so->split-1][next_pos].freq = work_nw[i];
            next_pos++;
          }
        }
      }
      if (prev_word_ord < curr_word_ord) {  // need to fetch counts
        for (size32_t i=0; i< num_topics; i++) work_nw[i] = 0;
        for (size32_t i=0; i<so->nw_c[curr_word_ord-so->split-1]; i++) {
          size32_t pos = so->nw_tf[curr_word_ord-so->split-1][i].topic-1;
          work_nw[pos] = so->nw_tf[curr_word_ord-so->split-1][i].freq;
        }
      }
      work_nw[old_topic-1]--;
    }
    // Collection topic/word counts are in so->nw or work_nw.  Calculate
    //cumulative probability table for topic selection
    int64_t t_nw = (curr_word_ord>so->split)
                 ? work_nw[0]
                 : so->nw[((curr_word_ord-1)*num_topics)];
    p[0] = ((t_nw + beta)/(so->nwsum[0] + so->uniq_words*beta))
        *((out_nd[0].freq + alpha)/((doc_words-1) + num_topics*alpha));
    for (uint32_t i=1; i<num_topics; i++) {
      t_nw = (curr_word_ord>so->split)
            ? work_nw[i]
            : so->nw[((curr_word_ord-1)*num_topics) + i];
      p[i] = p[i-1]
       + ((t_nw + beta)/(so->nwsum[i] + so->uniq_words*beta))
        *((out_nd[i].freq + alpha)/((doc_words-1) + num_topics*alpha));
    }
    // draw variable, assign topic
    //double draw = udis(gen);    // uniform distribution [0,1]
    double draw = std::rand() * denom * p[num_topics-1];  // scale draw
    uint32_t topic_ndx;
    for (topic_ndx=0; topic_ndx<num_topics-1 && draw > p[topic_ndx]; topic_ndx++);
    // update counts for new topic
    out_z[word].topic = topic_ndx+1;
    out_nd[topic_ndx].freq++;
    if (curr_word_ord<=so->split) { // a high freq word
      size32_t pos = ((curr_word_ord-1)*num_topics) + topic_ndx;
      so->nw[pos]++;
    } else { // a low freq word, use the exploded copy
      work_nw[topic_ndx]++;
    }
    so->nwsum[topic_ndx]++;
  }
  // see if we last updated sparse, and if so copy results
  uint32_t last_ordinal = in_z[doc_words-1].ordinal;
  if (last_ordinal > so->split) {
    int nz_entries = 0;
    for (size32_t i=0; i<num_topics; i++) {
      if(work_nw[i]>0) nz_entries++;
    }
    so->nw_c[last_ordinal-so->split-1] = nz_entries;
    size32_t next_pos = 0;
    for(size32_t i=0; i<num_topics; i++) {
      if (work_nw[i]>0) {
        so->nw_tf[last_ordinal-so->split-1][next_pos].topic = i+1;
        so->nw_tf[last_ordinal-so->split-1][next_pos].freq = work_nw[i];
        next_pos++;
      }
    }
  }
  rtlFree(work_nw);
  rtlFree(p);
ENDC++;

EXPORT Types.Sampling_Result
    resample_topics(Types.t_model_id model, UNSIGNED6 rid,
                    Types.Collection_Work_Handle hand, BOOLEAN isDoc,
                    UNSIGNED4 doc_words, UNSIGNED4 num_topics,
                    REAL8 alpha, REAL8 beta,
                    EMBEDDED DATASET(Types.MC_Freq) nd,
                    EMBEDDED DATASET(Types.MC_Term_Topic) z,
                    UNSIGNED4 uniq_words, Types.t_ordinal split, UNSIGNED4 pairs,
                    EMBEDDED DATASET(Types.MC_Freq) nwsum,
                    EMBEDDED DATASET(Types.MC_Freq) nw,
                    EMBEDDED DATASET(Types.MC_Term_Topic_Map) nwmap,
                    EMBEDDED DATASET(Types.MC_Topic_Freq) nwfreq)
    := TRANSFER(resample(model, rid, hand, isDoc, doc_words, num_topics,
                         alpha, beta, nd, z,
                         uniq_words, split, pairs, nwsum, nw,
                         nwmap, nwfreq), Types.Sampling_Result);
