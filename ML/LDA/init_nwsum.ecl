IMPORT $.Types AS Types;

EXPORT DATASET(Types.MC_Freq)
    init_nwsum(DATASET(Types.MC_Topic_Freq) topic_counts,
               UNSIGNED num_topics) := BEGINC++
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
  #body
  __lenResult = num_topics * sizeof(LDA_MC_Freq);
  __result = rtlMalloc(__lenResult);
  const LDA_MC_Topic_Freq* in_tc = (LDA_MC_Topic_Freq*) topic_counts;
  size32_t entries = lenTopic_counts/sizeof(LDA_MC_Topic_Freq);
  LDA_MC_Freq* nwsum = (LDA_MC_Freq*) __result;
  for (uint32_t i=0; i<num_topics; i++) nwsum[i].freq = 0;
  for (size32_t t=0; t<entries; t++) {
    nwsum[in_tc[t].topic-1].freq = in_tc[t].freq;
  }
ENDC++;