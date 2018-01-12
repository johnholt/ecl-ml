//Merge counts.  Usually a base and a delta.
//The word-topic counts have high frequency words in a dense array
// with one position for each word-topic count value.  The lower
// frequency words are held in a sparse array since most entries
// in a dense array would be zero.
IMPORT $.Types AS Types;

DATA mrgcounts(Types.t_model_id model, UNSIGNED4 num_topics,
              UNSIGNED4 uniq_words, Types.t_ordinal split,
              UNSIGNED4 l_pairs,
              DATASET(Types.MC_Freq) l_nwsum,
              DATASET(Types.MC_Freq) l_nw,
              DATASET(Types.MC_Term_Topic_Map) l_nwmap,
              DATASET(Types.MC_Topic_Freq) l_nwfreq,
              UNSIGNED4 r_pairs,
              DATASET(Types.MC_Freq) r_nwsum,
              DATASET(Types.MC_Freq) r_nw,
              DATASET(Types.MC_Term_Topic_Map) r_nwmap,
              DATASET(Types.MC_Topic_Freq) r_nwfreq) := BEGINC++
  ECLRTL_API unsigned rtlDisplay(unsigned len, const char * src);
  #include <stdio.h>
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
  #body
  const LDA_MC_Freq* in_l_nwsum = (LDA_MC_Freq*) l_nwsum;
  const LDA_MC_Freq* in_l_nw = (LDA_MC_Freq*) l_nw;
  const LDA_MC_Term_Topic_Map*in_l_nwmap=(LDA_MC_Term_Topic_Map*)l_nwmap;
  const LDA_MC_Topic_Freq* in_l_nwfreq = (LDA_MC_Topic_Freq*) l_nwfreq;
  const LDA_MC_Freq* in_r_nwsum = (LDA_MC_Freq*) r_nwsum;
  const LDA_MC_Freq* in_r_nw = (LDA_MC_Freq*) r_nw;
  const LDA_MC_Term_Topic_Map*in_r_nwmap=(LDA_MC_Term_Topic_Map*)r_nwmap;
  const LDA_MC_Topic_Freq* in_r_nwfreq = (LDA_MC_Topic_Freq*) r_nwfreq;
  // Step 1, determine the space required.  Space for sparse pairs
  //is variable.
  size32_t mrgd_pairs = 0;
  size32_t rare_words = uniq_words - split;
  for (size32_t word=0; word < rare_words; word++) {
    size32_t l_pos = 0;
    size32_t r_pos = 0;
    while (l_pos < in_l_nwmap[word].num_topics
        && r_pos < in_r_nwmap[word].num_topics) {
      size32_t l_ndx = in_l_nwmap[word].list_pos + l_pos;
      size32_t r_ndx = in_r_nwmap[word].list_pos + r_pos;
      uint32_t l_topic = in_l_nwfreq[l_ndx].topic;
      uint32_t r_topic = in_r_nwfreq[r_ndx].topic;
      if (l_topic < r_topic) {  //Q. topic on left not in right
        l_pos++;
        mrgd_pairs++;
      } else if (r_topic < l_topic) { //Q. Topic on right not in left
        r_pos++;
        mrgd_pairs++;
      } else {  // topics match, but will the count go to zero and be dropped?
        if(in_l_nwfreq[l_ndx].freq + in_r_nwfreq[r_ndx].freq != 0) mrgd_pairs++;
        r_pos++;
        l_pos++;
      }
    }
    if (r_pos < in_r_nwmap[word].num_topics) {  //Q. extra topics on right
      mrgd_pairs += in_r_nwmap[word].num_topics - r_pos;
    } else if (l_pos < in_l_nwmap[word].num_topics) { //Q. Extra topics on left
      mrgd_pairs += in_l_nwmap[word].num_topics - l_pos;
    }
  }
  // now we know the size of the result
  __lenResult = sizeof(LDA_MC_Collection_Work)
              + num_topics*sizeof(LDA_MC_Freq)           // nwsum
              + num_topics*split*sizeof(LDA_MC_Freq)     // nw
              + rare_words*sizeof(LDA_MC_Term_Topic_Map) // nwmap
              + mrgd_pairs*sizeof(LDA_MC_Topic_Freq);  // nwfreq
  __result = rtlMalloc(__lenResult);
  uint8_t* r_ptr = (uint8_t*) __result;
  LDA_MC_Collection_Work* rslt = (LDA_MC_Collection_Work*) __result;
  // calculate offsets for variable arrays
  size_t nwsum_offset = sizeof(LDA_MC_Collection_Work);
  size_t nw_offset = nwsum_offset + num_topics*sizeof(LDA_MC_Freq);
  size_t nwmap_offset = nw_offset
                      + num_topics*split*sizeof(LDA_MC_Freq);
  size_t nwfreq_offset = nwmap_offset
                       + (rare_words)*sizeof(LDA_MC_Term_Topic_Map);
  // Fill in fixed parts
  rslt->model = model;
  rslt->num_topics = num_topics;
  rslt->uniq_words = uniq_words;
  rslt->split = split;
  rslt->pairs = 0;  // count as we add them
  // nwsum
  LDA_MC_Freq* rslt_nwsum = (LDA_MC_Freq*) (r_ptr+nwsum_offset);
  for (size32_t t=0; t<num_topics; t++) {
    rslt_nwsum[t].freq = in_l_nwsum[t].freq + in_r_nwsum[t].freq;
  }
  // nw - dense array
  LDA_MC_Freq* rslt_nw = (LDA_MC_Freq*) (r_ptr+nw_offset);
  for (size32_t tw=0; tw<num_topics*split; tw++) {
    rslt_nw[tw].freq = in_l_nw[tw].freq + in_r_nw[tw].freq;
  }
  // nwmap and nwfreq
  LDA_MC_Term_Topic_Map* rslt_nwmap = (LDA_MC_Term_Topic_Map*)
                                      (r_ptr + nwmap_offset);
  LDA_MC_Topic_Freq* rslt_nwfreq = (LDA_MC_Topic_Freq*)
                                   (r_ptr + nwfreq_offset);
  // use a dense array to get counts for each word in turn
  int64_t* work_nw = (int64_t*) rtlMalloc(num_topics * sizeof(int64_t));
  for (size32_t word=0; word<rare_words; word++) {
    // clear the array
    for (size32_t t=0; t<num_topics; t++) work_nw[t] = 0;
    // load the left counts
    for (size32_t t=0; t<in_l_nwmap[word].num_topics; t++) {
      size32_t pos = in_l_nwmap[word].list_pos + t;
      size32_t t_ndx = in_l_nwfreq[pos].topic-1;
      work_nw[t_ndx] = in_l_nwfreq[pos].freq;
    }
    // add in the right counts
    for (size32_t t=0; t<in_r_nwmap[word].num_topics; t++) {
      size32_t pos = in_r_nwmap[word].list_pos + t;
      size32_t t_ndx = in_r_nwfreq[pos].topic-1;
      work_nw[t_ndx] += in_r_nwfreq[pos].freq;
    }
    rslt_nwmap[word].num_topics = 0;
    rslt_nwmap[word].list_pos = rslt->pairs;
    // record the topic and count pairs with non-zero count
    for (size32_t t=0; t<num_topics; t++) {
      if (work_nw[t] == 0) continue;
      rslt_nwmap[word].num_topics++;
      if (rslt->pairs>=mrgd_pairs) rtlFail(0,"Used pairs exceeds calc");
      rslt_nwfreq[rslt->pairs].topic = t+1;
      rslt_nwfreq[rslt->pairs].freq = work_nw[t];
      rslt->pairs++;
    }
  }
  rtlFree(work_nw);
  if (mrgd_pairs!=rslt->pairs) rtlFail(0, "Error in pairs calculation");
ENDC++;

EXPORT Types.Collection_Work
     mrg_counts(Types.t_model_id model, UNSIGNED4 num_topics,
              UNSIGNED4 uniq_words, Types.t_ordinal split,
              UNSIGNED4 l_pairs,
              DATASET(Types.MC_Freq) l_nwsum,
              DATASET(Types.MC_Freq) l_nw,
              DATASET(Types.MC_Term_Topic_Map) l_nwmap,
              DATASET(Types.MC_Topic_Freq) l_nwfreq,
              UNSIGNED4 r_pairs,
              DATASET(Types.MC_Freq) r_nwsum,
              DATASET(Types.MC_Freq) r_nw,
              DATASET(Types.MC_Term_Topic_Map) r_nwmap,
              DATASET(Types.MC_Topic_Freq) r_nwfreq)
    := TRANSFER(mrgcounts(model, num_topics, uniq_words, split,
                           l_pairs, l_nwsum, l_nw, l_nwmap, l_nwfreq,
                           r_pairs, r_nwsum, r_nw, r_nwmap, r_nwfreq),
                Types.Collection_Work);
