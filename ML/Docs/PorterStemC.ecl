STRING stem(STRING word) := EMBED(C++ : DISTRIBUTED)

/* This is the Porter stemming algorithm presented in

   Porter, 1980, An algorithm for suffix stripping, Program, Vol. 14,
   no. 3, pp 130-137

   See also http://www.tartarus.org/~martin/PorterStemmer
*/

#include <string.h>  /* for memmove */

#option pure

class PorterStemmerClass
{
    private:

        /* The main part of the stemming algorithm starts here. b is a buffer
        holding a word to be stemmed. The letters are in b[k0], b[k0+1] ...
        ending at b[k]. In fact k0 = 0 in this demo program. k is readjusted
        downwards as the stemming progresses. Zero termination is not in fact
        used in the algorithm.

        Note that only lower case sequences are stemmed. Forcing to lower case
        should be done before stem(...) is called.
        */

        char * b = NULL;    /* buffer for word to be stemmed */
        int k = 0;
        int k0 = 0;
        int j = 0;          /* j is a general offset into the string */

    public:

        PorterStemmerClass()
        : b(NULL), k(0), k0(0), j(0)
        {}

        /* cons(i) is TRUE <=> b[i] is a consonant. */

        bool cons(int i)
        {
            switch (b[i])
            {
                case 'a':
                case 'e':
                case 'i':
                case 'o':
                case 'u':
                    return false;

                case 'y':
                    return (i==k0) ? true : !cons(i - 1);

                default:
                    return true;
            }
        }

        /* m() measures the number of consonant sequences between k0 and j. if c is
        a consonant sequence and v a vowel sequence, and <..> indicates arbitrary
        presence,

            <c><v>       gives 0
            <c>vc<v>     gives 1
            <c>vcvc<v>   gives 2
            <c>vcvcvc<v> gives 3
            ....
        */

        int m()
        {
            int n = 0;
            int i = k0;

            while(true)
            {
                if (i > j)
                    return n;
                if (!cons(i))
                    break;
                i++;
            }

            i++;

            while(true)
            {
                while(true)
                {
                    if (i > j)
                        return n;
                    if (cons(i))
                        break;
                    i++;
                }

                i++;
                n++;

                while(true)
                {
                    if (i > j)
                        return n;
                    if (!cons(i))
                        break;
                    i++;
                }

                i++;
            }
        }

        /* vowelinstem() is TRUE <=> k0,...j contains a vowel */

        bool vowelinstem()
        {
            for (int i = k0; i <= j; i++)
            {
                if (!cons(i))
                    return true;
            }

            return false;
        }

        /* doublec(j) is TRUE <=> j,(j-1) contain a double consonant. */

        bool doublec(int j)
        {
            if (j < k0 + 1)
                return false;

            if (b[j] != b[j - 1])
                return false;

            return cons(j);
        }

        /* cvc(i) is TRUE <=> i-2,i-1,i has the form consonant - vowel - consonant
        and also if the second c is not w,x or y. this is used when trying to
        restore an e at the end of a short word. e.g.

            cav(e), lov(e), hop(e), crim(e), but
            snow, box, tray.

        */

        bool cvc(int i)
        {
            if (i < k0 + 2 || !cons(i) || cons(i - 1) || !cons(i - 2))
                return false;

            int ch = b[i];

            if (ch == 'w' || ch == 'x' || ch == 'y')
                return false;

            return true;
        }

        /* ends(s) is TRUE <=> k0,...k ends with the string s. */

        bool ends(const char * s)
        {
            int length = s[0];

            if (s[length] != b[k])
                return false; /* tiny speed-up */

            if (length > k - k0 + 1)
                return false;

            if (memcmp(b + k - length + 1, s + 1, length) != 0)
                return false;

            j = k - length;

            return true;
        }

        /* setto(s) sets (j+1),...k to the characters in the string s, readjusting
        k. */

        void setto(const char * s)
        {
            int length = s[0];

            memmove(b + j + 1, s + 1, length);
            k = j + length;
        }

        /* r(s) is used further down. */

        void r(const char * s)
        {
            if (m() > 0)
                setto(s);
        }

        /* step1ab() gets rid of plurals and -ed or -ing. e.g.

            caresses  ->  caress
            ponies    ->  poni
            ties      ->  ti
            caress    ->  caress
            cats      ->  cat

            feed      ->  feed
            agreed    ->  agree
            disabled  ->  disable

            matting   ->  mat
            mating    ->  mate
            meeting   ->  meet
            milling   ->  mill
            messing   ->  mess

            meetings  ->  meet

        */

        void step1ab()
        {
            if (b[k] == 's')
            {
                if (ends("\04" "sses"))
                    k -= 2;
                else if (ends("\03" "ies"))
                    setto("\01" "i");
                else if (b[k - 1] != 's')
                    k--;
            }

            if (ends("\03" "eed"))
            {
                if (m() > 0)
                k--;
            }
            else if ((ends("\02" "ed") || ends("\03" "ing")) && vowelinstem())
            {
                k = j;
                if (ends("\02" "at"))
                    setto("\03" "ate");
                else if (ends("\02" "bl"))
                    setto("\03" "ble");
                else if (ends("\02" "iz"))
                    setto("\03" "ize");
                else if (doublec(k))
                {
                    k--;

                    int ch = b[k];
                    if (ch == 'l' || ch == 's' || ch == 'z')
                        k++;
                }
                else if (m() == 1 && cvc(k))
                    setto("\01" "e");
            }
        }

        /* step1c() turns terminal y to i when there is another vowel in the stem. */

        void step1c()
        {
            if (ends("\01" "y") && vowelinstem())
                b[k] = 'i';
        }


        /* step2() maps double suffices to single ones. so -ization ( = -ize plus
        -ation) maps to -ize etc. note that the string before the suffix must give
        m() > 0. */

        void step2()
        {
            switch (b[k - 1])
            {
                case 'a':
                    {
                        if (ends("\07" "ational"))
                            r("\03" "ate");
                        else if (ends("\06" "tional"))
                            r("\04" "tion");
                    }
                    break;

                case 'c':
                    {
                        if (ends("\04" "enci"))
                            r("\04" "ence");
                        else if (ends("\04" "anci"))
                            r("\04" "ance");
                    }
                    break;

                case 'e':
                    {
                        if (ends("\04" "izer"))
                            r("\03" "ize");
                    }
                    break;

                case 'l':
                    {
                        if (ends("\03" "bli"))
                            r("\03" "ble");
                        else if (ends("\04" "alli"))
                            r("\02" "al");
                        else if (ends("\05" "entli"))
                            r("\03" "ent");
                        else if (ends("\03" "eli"))
                            r("\01" "e");
                        else if (ends("\05" "ousli"))
                            r("\03" "ous");
                    }
                    break;

                case 'o':
                    {
                        if (ends("\07" "ization"))
                            r("\03" "ize");
                        else if (ends("\05" "ation"))
                            r("\03" "ate");
                        else if (ends("\04" "ator"))
                            r("\03" "ate");
                    }
                    break;

                case 's':
                    {
                        if (ends("\05" "alism"))
                            r("\02" "al");
                        else if (ends("\07" "iveness"))
                            r("\03" "ive");
                        else if (ends("\07" "fulness"))
                            r("\03" "ful");
                        else if (ends("\07" "ousness"))
                            r("\03" "ous");
                    }
                    break;

                case 't':
                    {
                        if (ends("\05" "aliti"))
                            r("\02" "al");
                        else if (ends("\05" "iviti"))
                            r("\03" "ive");
                        else if (ends("\06" "biliti"))
                            r("\03" "ble");
                    }
                    break;

                case 'g':
                    {
                        if (ends("\04" "logi"))
                            r("\03" "log");
                    }
                    break;

            }
        }

        /* step3() deals with -ic-, -full, -ness etc. similar strategy to step2. */

        void step3()
        {
            switch (b[k])
            {
                case 'e':
                    {
                        if (ends("\05" "icate"))
                            r("\02" "ic");
                        else if (ends("\05" "ative"))
                            r("\00" "");
                        else if (ends("\05" "alize"))
                            r("\02" "al");
                    }
                    break;

                case 'i':
                    {
                        if (ends("\05" "iciti"))
                            r("\02" "ic");
                    }
                    break;

                case 'l':
                    {
                        if (ends("\04" "ical"))
                            r("\02" "ic");
                        else if (ends("\03" "ful"))
                            r("\00" "");
                    }
                    break;

                case 's':
                    {
                        if (ends("\04" "ness"))
                            r("\00" "");
                    }
                    break;
            }
        }

        /* step4() takes off -ant, -ence etc., in context <c>vcvc<v>. */

        void step4()
        {
            switch (b[k - 1])
            {
                case 'a':
                    {
                        if (ends("\02" "al"))
                            break;
                        return;
                    }

                case 'c':
                    {
                        if (ends("\04" "ance"))
                            break;
                        if (ends("\04" "ence"))
                            break;
                        return;
                    }

                case 'e':
                    {
                        if (ends("\02" "er"))
                            break;
                        return;
                    }

                case 'i':
                    {
                        if (ends("\02" "ic"))
                            break;
                        return;
                    }

                case 'l':
                    {
                        if (ends("\04" "able"))
                            break;
                        if (ends("\04" "ible"))
                            break;
                        return;
                    }

                case 'n':
                    {
                        if (ends("\03" "ant"))
                            break;
                        if (ends("\05" "ement"))
                            break;
                        if (ends("\04" "ment"))
                            break;
                        if (ends("\03" "ent"))
                            break;
                        return;
                    }

                case 'o':
                    {
                        if (ends("\03" "ion") && (b[j] == 's' || b[j] == 't'))
                            break;
                        if (ends("\02" "ou"))
                            break;
                        return;
                    }

                case 's':
                    {
                        if (ends("\03" "ism"))
                            break;
                        return;
                    }

                case 't':
                    {
                        if (ends("\03" "ate"))
                            break;
                        if (ends("\03" "iti"))
                            break;
                        return;
                    }

                case 'u':
                    {
                        if (ends("\03" "ous"))
                            break;
                        return;
                    }

                case 'v':
                    {
                        if (ends("\03" "ive"))
                            break;
                        return;
                    }
                case 'z':
                    {
                        if (ends("\03" "ize"))
                            break;
                        return;
                    }

                default:
                    return;
            }

            if (m() > 1)
                k = j;
        }

        /* step5() removes a final -e if m() > 1, and changes -ll to -l if
        m() > 1. */

        void step5()
        {
            j = k;
            if (b[k] == 'e')
            {
                int a = m();

                if (a>1 || (a==1 && !cvc(k - 1))) // made explicit with parentheses
                    k--;
            }

            if (b[k] == 'l' && doublec(k) && m() > 1)
                k--;
        }

        /* In stem(p,i,j), p is a char pointer, and the string to be stemmed is from
        p[i] to p[j] inclusive. Typically i is zero and j is the offset to the last
        character of a string, (p[j+1] == '\0'). The stemmer adjusts the
        characters p[i] ... p[j] and returns the new end-point of the string, k.
        Stemming never increases word length, so i <= k <= j. To turn the stemmer
        into a module, declare 'stem' as extern, and delete the remainder of this
        file.
        */

        int stem(char * p, int i, int j)
        {
            b = p; k = j; k0 = i; /* copy the parameters into statics */

            if (k <= k0 + 1)
                return k; /*-DEPARTURE-*/

            /* With this line, strings of length 1 or 2 don't go through the
                stemming process, although no mention is made of this in the
                published algorithm. Remove the line to match the published
                algorithm. */

            step1ab();
            step1c();
            step2();
            step3();
            step4();
            step5();

            return k;
        }
};

#body

    __result = NULL;
    __lenResult = 0;

    if (lenWord > 0)
    {
        // Make a copy of the input word
        char * s = (char *)rtlMalloc(lenWord);
        memcpy(s, word, lenWord);

        // Point our result buffer to the copy
        __result = s;

        // We can stem words up to 255 characters in length
        if (lenWord < 256)
        {
            PorterStemmerClass porter;
            int lastCharOffset = porter.stem(s, 0, lenWord - 1);

            __lenResult = lastCharOffset + 1;
        }
        else
        {
            // Word is too long; set the length of the returned string to the
            // length of input that we have already copied
            __lenResult = lenWord;
        }
    }
ENDEMBED;

EXPORT STRING PorterStemC(STRING word) := FUNCTION
    RETURN stem(word);
END;
