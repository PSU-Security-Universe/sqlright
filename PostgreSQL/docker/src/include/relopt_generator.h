#ifndef RELOPT_GENERATOR_H_
#define RELOPT_GENERATOR_H_

#include <utility>
#include <string>

using namespace std;

#ifndef INT_MAX
#define INT_MAX 2147483647
#endif

enum RelOptionType {
Unknown,
StorageParameters,
SetConfigurationOptions,
AlterAttribute,
AlterAttributeReset
};

class RelOptionGenerator {

public:
    static bool get_rel_option_pair(RelOptionType, pair<string, string>&);

private:
    static pair<string, string> get_rel_option_storage_parameters();
    static pair<string, string> get_rel_option_set_configuration_options();
    static pair<string, string> get_rel_option_alter_attribute();
};

#endif // RELOPT_GENERATOR_H_
