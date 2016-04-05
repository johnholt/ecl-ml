IMPORT $.Types AS Types;

EXPORT DATASET(Types.MC_Freq)
    init_doc_nd(DATASET(Types.MC_Term_Topic) z, UNSIGNED4 num_topics,
                UNSIGNED4 doc_words):=BEGINC++
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
  #body
  __lenResult = num_topics * sizeof(LDA_MC_Freq);
  __result = rtlMalloc(__lenResult);
  const LDA_MC_Term_Topic* in_tt = (LDA_MC_Term_Topic*) z;
  if(doc_words*sizeof(LDA_MC_Term_Topic)!=lenZ) rtlFail(0,"z length");
  LDA_MC_Freq* nd = (LDA_MC_Freq*) __result;
  for (uint32_t i=0; i<num_topics; i++) nd[i].freq = 0;
  for (uint32_t w=0; w<doc_words; w++) nd[in_tt[w].topic-1].freq++;
ENDC++;