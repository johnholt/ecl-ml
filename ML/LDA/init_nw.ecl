IMPORT $.Types AS Types;

EXPORT DATASET(Types.MC_Freq)
    init_nw(DATASET(Types.MC_Term_Topic_Freq) ttf, Types.t_ordinal split,
            UNSIGNED4 num_topics) := BEGINC++;
  #ifndef LDA_MC_TERM_TOPIC_FREQ
  #define LDA_MC_TERM_TOPIC_FREQ
  struct __attribute__ ((__packed__)) LDA_MC_Term_Topic_Freq {
    uint32_t ordinal;
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
  size32_t entries = num_topics*split;
  __lenResult = entries*sizeof(LDA_MC_Freq);
  __result = rtlMalloc(__lenResult);
  LDA_MC_Freq* nw = (LDA_MC_Freq*) __result;
  const LDA_MC_Term_Topic_Freq* in_ttf = (LDA_MC_Term_Topic_Freq*)ttf;
  const size32_t ttf_entries = lenTtf/sizeof(LDA_MC_Term_Topic_Freq);
  for (size32_t i=0; i<entries; i++) nw[i].freq = 0;
  for (size32_t i=0; i<ttf_entries; i++) {
    size32_t topic_ndx = in_ttf[i].topic-1;
    size32_t ord_ndx = in_ttf[i].ordinal - 1;
    size32_t pos = (ord_ndx*num_topics) + topic_ndx;
    nw[pos].freq = in_ttf[i].freq;
  }
ENDC++;