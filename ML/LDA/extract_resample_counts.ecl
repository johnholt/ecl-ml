//Extract the counts from the memory object after re-sampling the
// the document topic distribution for all of the documents
IMPORT $ AS LDA;
IMPORT $.Types AS Types;
//
DATA extract_counts(Types.t_model_id model,
                    Types.Collection_Work_Handle hand,
                    BOOLEAN noop, BOOLEAN free) := BEGINC++
  //
  ECLRTL_API unsigned rtlDisplay(unsigned len, const char * src);
  #include <stdio.h>
  #include <cstdlib>
  #include <ctime>
  #ifndef LDA_MC_COLLECTION_WORK
  #define LDA_MC_COLLECTION_WORK
  struct __attribute__ ((__packed__)) LDA_MC_Collection_Work {
    uint16_t model;
    uint32_t num_topics;
    uint32_t uniq_words;
    uint32_t split;
    uint32_t pairs;   //topic/freq pairs for a word in sparse array
    //nwsum[num_topics], nw[split*num_topics],
    //nwmap[uniq_words-split], and nwfreq[pairs] arrays
  };
  #endif
  #ifndef LDA_MC_TOPIC_FREQ
  #define LDA_MC_TOPIC_FREQ
  struct __attribute__ ((__packed__)) LDA_MC_Topic_Freq {
    uint32_t topic;
    int64_t freq;
  };
  #endif
  #ifndef LDA_MC_FREQ
  #define LDA_MC_FREQ
  struct __attribute__ ((__packed__)) LDA_MC_Freq {
    int64_t freq;
  };
  #endif
  #ifndef LDA_MC_TERM_TOPIC_MAP
  #define LDA_MC_TERM_TOPIC_MAP
  struct __attribute__ ((__packed__)) LDA_MC_Term_Topic_Map {
    uint32_t num_topics; //
    uint32_t list_pos;   // zero based
  };
  #endif
  #ifndef LDA_MC_TERM_TOPIC
  #define LDA_MC_TERM_TOPIC
  struct __attribute__ ((__packed__)) LDA_MC_Term_Topic {
    uint32_t ordinal;
    uint32_t topic;
  };
  #endif
  #ifndef LDA_MC_SAMPLING_OBJECT
  #define LDA_MC_SAMPLING_OBJECT
  struct __attribute__ ((__packed__)) LDA_MC_Sampling_Object {
    uint16_t model;
    uint32_t num_topics;
    uint32_t uniq_words;
    uint32_t split;
    int64_t *nwsum;   //[num_topics]
    int64_t *nw;      //[split*num_topics]
    uint32_t *nw_c;   //[uniq_words-split], number of topics
    LDA_MC_Topic_Freq **nw_tf;   //[uniq_words-split][freq]
  };
  #endif
  // #DEFINE LDA_MCMC_LOGGING
  #body
  // find the number of low frequency topic/freq pairs
  LDA_MC_Sampling_Object *so = (LDA_MC_Sampling_Object*) hand;
  if(so->model!=model) rtlFail(0, "Corrupt object, model mismatch");
  if(so->uniq_words<so->split) rtlFail(0, "Corrupt object, vocab");
  // Null object, base for a no_op return
  LDA_MC_Sampling_Object dummy_so;
  dummy_so.model = model;
  dummy_so.num_topics = 0;
  dummy_so.uniq_words = 0;
  dummy_so.split = 0;
  if (noop) so = &dummy_so;
  uint32_t rare_words = so->uniq_words - so->split;
  uint32_t pairs = 0;
  for (uint32_t word=0; word<rare_words; word++) pairs += so->nw_c[word];
  // Allocate return
  __lenResult = sizeof(LDA_MC_Collection_Work)
              + so->num_topics*sizeof(LDA_MC_Freq)          // nwsum
              + so->num_topics*so->split*sizeof(LDA_MC_Freq)// nw
              + rare_words*sizeof(LDA_MC_Term_Topic_Map)    // nwmap
              + pairs*sizeof(LDA_MC_Topic_Freq);            // nwfreq
  __result = rtlMalloc(__lenResult);
  uint8_t* r_ptr = (uint8_t*) __result;
  // Determine offsets for pointers
  size_t nwsum_offset = sizeof(LDA_MC_Collection_Work);
  size_t nw_offset = nwsum_offset + so->num_topics*sizeof(LDA_MC_Freq);
  size_t nwmap_offset = nw_offset
                      + so->num_topics*so->split*sizeof(LDA_MC_Freq);
  size_t nwfreq_offset = nwmap_offset
                       + rare_words*sizeof(LDA_MC_Term_Topic_Map);
  // Copy data into output buffer
  LDA_MC_Collection_Work* rslt = (LDA_MC_Collection_Work*) r_ptr;
  rslt->model = so->model;
  rslt->num_topics = so->num_topics;
  rslt->uniq_words = so->uniq_words;
  rslt->split = so->split;
  rslt->pairs = pairs;
  LDA_MC_Freq* out_nwsum = (LDA_MC_Freq*)(r_ptr+nwsum_offset);
  for (size32_t i=0; i< so->num_topics; i++) {
    out_nwsum[i].freq = so->nwsum[i];
  }
  LDA_MC_Freq* out_nw = (LDA_MC_Freq*)(r_ptr+nw_offset);
  for (size32_t i=0; i<so->num_topics*so->split; i++) {
    out_nw[i].freq = so->nw[i];
  }
  LDA_MC_Term_Topic_Map* out_nwmap = (LDA_MC_Term_Topic_Map*)
                                     (r_ptr+nwmap_offset);
  LDA_MC_Topic_Freq* out_nwfreq = (LDA_MC_Topic_Freq*)
                                  (r_ptr+nwfreq_offset);
  size32_t next_tf_pos = 0; // topic freq array, filled in as we go
  for (uint32_t word=0; word<rare_words; word++) {
    out_nwmap[word].num_topics = so->nw_c[word];
    out_nwmap[word].list_pos = next_tf_pos;
    for (uint32_t i=0; i<so->nw_c[word]; i++) {
      out_nwfreq[next_tf_pos].topic = so->nw_tf[word][i].topic;
      out_nwfreq[next_tf_pos].freq = so->nw_tf[word][i].freq;
      next_tf_pos++;
    }
  }
  // free objects before exit?
  #ifdef LDA_MCMC_LOGGING
  if (free==true) {
    char buffer[200];
    sprintf(buffer, "*****Free request, model %d, handle %lld, noop %d ",
             model, hand, noop);
    rtlDisplay(strlen(buffer), buffer);
  }
  #endif
  if (free==true && noop==false) {
    so->model = 0;
    so->num_topics = 0;
    so->uniq_words = 0;
    so->split = 0;
    rtlFree(so->nwsum);
    rtlFree(so->nw);
    rtlFree(so->nw_c);
    for (uint32_t word=0; word<rare_words; word++) rtlFree(so->nw_tf[word]);
    rtlFree(so->nw_tf);
  }
  // all done, __lenResult and __result already set
ENDC++;

EXPORT Types.Collection_Work
    extract_resample_counts(Types.t_model_id model,
                            Types.Collection_Work_Handle hand,
                            BOOLEAN noop, BOOLEAN free)
    := TRANSFER(extract_counts(model, hand, noop, free), Types.Collection_Work);
