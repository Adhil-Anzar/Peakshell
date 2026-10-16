// Exprtk calculator backend for the launcher.
// Uses OpenSearch's exprtk.hpp copy as-is (same compile pattern as
// OpenSearch SearchFilters::calculate). This TU is built with -w (see
// CMakeLists.txt) since exprtk is a third-party header.

#include "calculator.h"

// NOTE: exprtk.hpp is intentionally never opened in the editor (44k lines);
// it is only included here, exactly like OpenSearch does in searchfilters.cpp.
#include "exprtk/exprtk.hpp"

namespace peakshell::apps {

bool tryEvaluateExpression(const QString& query, double& result) {
    const QString trimmed = query.trimmed();
    if (trimmed.isEmpty())
        return false;

    typedef exprtk::symbol_table<double> symbol_table_t;
    typedef exprtk::expression<double> expression_t;
    typedef exprtk::parser<double> parser_t;

    expression_t expression;
    symbol_table_t symbol_table;
    expression.register_symbol_table(symbol_table);

    parser_t parser;
    if (!parser.compile(trimmed.toStdString(), expression))
        return false;

    result = expression.value();
    return true;
}

} // namespace peakshell::apps
