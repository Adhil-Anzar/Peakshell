#include "fuzzysearch.h"
#include "Matrix.h"

FuzzySearch::FuzzySearch() {}
double FuzzySearch::getMatch(const std::string &s1, const std::string &s2){

    auto first1 = std::begin(s1);
    auto last1 = std::end(s1);
    auto first2 = std::begin(s2);
    auto last2 = std::end(s2);
    return FuzzySearch::ratio(first1,last1,first2,last2);
}

double FuzzySearch::getPartialMatch(const std::string &s1, const std::string &s2){

    auto first1 = std::begin(s1);
    auto last1 = std::end(s1);
    auto first2 = std::begin(s2);
    auto last2 = std::end(s2);

    size_t len1 = static_cast<size_t>(std::distance(first1, last1));
    size_t len2 = static_cast<size_t>(std::distance(first2, last2));
    if (len1 != len2) return FuzzySearch::partial_ratio_impl(first1, last1, first2, last2);

    return std::max(FuzzySearch::partial_ratio_impl(first1, last1, first2, last2),
                    FuzzySearch::partial_ratio_impl(first2, last2, first1, last1));
}
double FuzzySearch::ratio(std::string::const_iterator &first1,
                          std::string::const_iterator &last1,
                          std::string::const_iterator &first2,
                          std::string::const_iterator &last2)
{
    size_t len1 = static_cast<size_t>(std::distance(first1, last1));
    size_t len2 = static_cast<size_t>(std::distance(first2, last2));

    Matrix<size_t> matrix(len1 + 1, len2 + 1);

    for (size_t i = 0; i <= len1; ++i)
        matrix(i, 0) = i;
    for (size_t i = 0; i <= len2; ++i)
        matrix(0, i) = i;

    for (size_t pos1 = 0; pos1 < len1; ++pos1) {
        for (size_t pos2 = 0; pos2 < len2; ++pos2) {
            using diff_t = std::string::difference_type;
            size_t cost = (first1[static_cast<diff_t>(pos1)] == first2[static_cast<diff_t>(pos2)]) ? 0 : 2;

            matrix(pos1 + 1, pos2 + 1) =
                std::min({matrix(pos1, pos2 + 1) + 1,
                          matrix(pos1 + 1, pos2) + 1, matrix(pos1, pos2) + cost});
        }
    }

    size_t dist = matrix.back();
    size_t max = len1 * 1 + len2 * 1;

    if (len1 >= len2)
        max = std::min(max, len2 * 2 + (len1 - len2) * 1);
    else
        max = std::min(max, len1 * 2 + (len2 - len1) * 1);

    double sim = (1.0 - static_cast<double>(dist) / static_cast<double>(max)) * 100;
    return sim;
}


double FuzzySearch::partial_ratio_impl(std::string::const_iterator &first1,
                          std::string::const_iterator &last1,
                          std::string::const_iterator &first2,
                          std::string::const_iterator &last2)
{
    size_t len1 = static_cast<size_t>(std::distance(first1, last1));
    size_t len2 = static_cast<size_t>(std::distance(first2, last2));

    if (len1 == 0 && len2 == 0) return 100.0;
    if (len1 == 0 || len2 == 0) return 0.0;
    if (len1 > len2) return partial_ratio_impl(first2, last2, first1, last1);;

    double res = 0.0;
    for (ptrdiff_t i = -1 * static_cast<ptrdiff_t>(len1); i < static_cast<ptrdiff_t>(len2); i++) {
        ptrdiff_t start = std::max(ptrdiff_t(0), i);
        ptrdiff_t end = std::min(ptrdiff_t(len2), i + ptrdiff_t(len1));
        auto first2_ = first2 + start;
        auto last2_ = first2 + end;
        res = std::max(res, FuzzySearch::ratio(first1, last1, first2_, last2_));
    }
    return res;
}

