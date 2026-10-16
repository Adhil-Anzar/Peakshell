#pragma once
#include <string>

class FuzzySearch
{
public:
    FuzzySearch();
    static double getMatch(const std::string &s1, const std::string &s2);
    static double getPartialMatch(const std::string &s1, const std::string &s2);
private:
    static double partial_ratio_impl(std::string::const_iterator &first1,
                                     std::string::const_iterator &last1,
                                     std::string::const_iterator &first2,
                                     std::string::const_iterator &last2);
    static double ratio(std::string::const_iterator &first1,
                        std::string::const_iterator &last1,
                        std::string::const_iterator &first2,
                        std::string::const_iterator &last2);
};
