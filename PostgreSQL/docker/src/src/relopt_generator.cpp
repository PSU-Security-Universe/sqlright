#include "../include/relopt_generator.h"
#include "../include/utils.h"

bool RelOptionGenerator::get_rel_option_pair(RelOptionType type, pair<string, string>& res_pair) {

    switch (type) {
        case StorageParameters: {
            res_pair = get_rel_option_storage_parameters();
            return false;
        }
        case SetConfigurationOptions: {
            res_pair = get_rel_option_set_configuration_options();
            if (get_rand_int(2)) {
                res_pair.second = "DEFAULT";
            }
            return false;
        }
        case AlterAttribute: {
            res_pair = get_rel_option_alter_attribute();
            return false;
        }
        case AlterAttributeReset: {
            res_pair = get_rel_option_alter_attribute();
            return true;
        }
        // TODO:: More options here...
        default: {
            assert(false && "Getting unknown options in the get_rel_option_pair functions. \n");
        }
    }

}


pair<string, string> RelOptionGenerator::get_rel_option_storage_parameters() {

    int rand_choice = get_rand_int(13);

    switch (rand_choice) {
        case 0: {
            string f = "fillfactor";
            int s_int = get_rand_int(10, 100);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 1: {
            string f = "parallel_workers";
            int s_int = get_rand_int(1024);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 2: {
            string f = "autovacuum_enabled";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 3: {
            string f = "autovacuum_vacuum_threshold";
            int s_int = get_rand_int(2147483647);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 4: {
            string f = "oids";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 5: {
            string f = "autovacuum_vacuum_scale_factor";
            vector<float> s_v_float = {0.0, 0.00001, 0.01, 0.1, 0.2, 0.5, 0.8, 0.9, 1.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 6: {
            string f = "autovacuum_analyze_threshold";
            int s_int = get_rand_int(INT_MAX);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 7: {
            string f = "autovacuum_analyze_scale_factor";
            vector<float> s_v_float = {0.0, 0.00001, 0.01, 0.1, 0.2, 0.5, 0.8, 0.9, 1.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 8: {
            string f = "autovacuum_vacuum_cost_delay";
            int s_int = get_rand_int(100);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 9: {
            string f = "autovacuum_vacuum_cost_limit";
            int s_int = get_rand_int(1, 10000);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 10: {
            string f = "autovacuum_freeze_min_age";
            long long s_int = get_rand_long_long(0, 1000000000);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 11: {
            string f = "autovacuum_freeze_max_age";
            long long s_int = get_rand_long_long(100000, 2000000000);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 12: {
            string f = "autovacuum_freeze_table_age";
            long long s_int = get_rand_long_long(0, 2000000000);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        default: {
            assert(false && "Fatal Error: Finding unknown type in the get_rel_option_storage_parameters function. \n");
            return make_pair("", "");
        }
    }
}

pair<string, string> RelOptionGenerator::get_rel_option_set_configuration_options() {

    int cur_choice = get_rand_int(66);

    switch(cur_choice) {
        case 0: {
            string f = "synchronous_commit";
            vector<string> v_str = {"remote_apply", "remote_write", "local", "off"};
            string s = vector_rand_ele(v_str);
            return make_pair(f, s);
        }
        case 1: {
            string f = "wal_compression";
            int rand_int = get_rand_int(2);
            string s = to_string(rand_int);
            return make_pair(f, s);
        }
        case 2: {
            string f = "commit_delay";
            int rand_int = get_rand_int(100000);
            string s = to_string(rand_int);
            return make_pair(f, s);
        }
        case 3: {
            string f = "commit_siblings";
            int rand_int = get_rand_int(1000);
            string s = to_string(rand_int);
            return make_pair(f, s);
        }
        case 4: {
            string f = "commit_siblings";
            int rand_int = get_rand_int(1000);
            string s = to_string(rand_int);
            return make_pair(f, s);
        }
        case 5: {
            string f = "commit_siblings";
            int rand_int = get_rand_int(2);
            string s = to_string(rand_int);
            return make_pair(f, s);
        }
        case 6: {
            string f = "track_counts";
            int rand_int = get_rand_int(2);
            string s = to_string(rand_int);
            return make_pair(f, s);
        }
        case 7: {
            string f = "track_io_timing";
            int rand_int = get_rand_int(2);
            string s = to_string(rand_int);
            return make_pair(f, s);
        }
        case 8: {
            string f = "track_functions";
            vector<string> s_v_str = {"'none'", "'pl'", "'all'"};
            string s = vector_rand_ele(s_v_str);
            return make_pair(f, s);
        }
        case 9: {
            string f = "vacuum_freeze_table_age";
            vector<long long> s_v_int = {0, 5, 10, 100, 500, 2000000000};
            long long s_int = vector_rand_ele(s_v_int);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 10: {
            string f = "vacuum_multixact_freeze_table_age";
            vector<long long> s_v_int = {0, 5, 10, 100, 500, 2000000000};
            long long s_int = vector_rand_ele(s_v_int);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 11: {
            string f = "vacuum_multixact_freeze_min_age";
            vector<long long> s_v_int = {0, 5, 10, 100, 500, 1000000000};
            long long s_int = vector_rand_ele(s_v_int);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 12: {
            string f = "vacuum_cleanup_index_scale_factor";
            vector<float> s_v_int = {0.0, 0.0000001, 0.00001, 0.01, 0.1, 1.0, 10.0, 100.0, 100000.0, 10000000000.0};
            float s_int = vector_rand_ele(s_v_int);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 13: {
            string f = "gin_fuzzy_search_limit";
            int s_int = get_rand_int(2147483647);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 14: {
            string f = "default_with_oids";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 15: {
            string f = "synchronize_seqscans";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 16: {
            string f = "synchronize_seqscans";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 17: {
            string f = "enable_bitmapscan";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 18: {
            string f = "enable_gathermerge";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 19: {
            string f = "enable_hashjoin";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 20: {
            string f = "enable_indexscan";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 21: {
            string f = "enable_indexonlyscan";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 22: {
            string f = "enable_material";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 23: {
            string f = "enable_mergejoin";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 24: {
            string f = "enable_nestloop";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 25: {
            string f = "enable_parallel_append";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 26: {
            string f = "enable_parallel_hash";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 27: {
            string f = "enable_partition_pruning";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 28: {
            string f = "enable_partitionwise_join";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 29: {
            string f = "enable_partitionwise_aggregate";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 30: {
            string f = "enable_seqscan";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 31: {
            string f = "enable_sort";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 32: {
            string f = "enable_tidscan";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 33: {
            string f = "seq_page_cost";
            vector<float> s_v_float = {0.0, 0.00001, 0.05, 0.1, 1.0, 10.0, 10000.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 34: {
            string f = "random_page_cost";
            vector<float> s_v_float = {0.0, 0.00001, 0.05, 0.1, 1.0, 10.0, 10000.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 35: {
            string f = "cpu_tuple_cost";
            vector<float> s_v_float = {0.0, 0.00001, 0.05, 0.1, 1.0, 10.0, 10000.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 36: {
            string f = "cpu_index_tuple_cost";
            vector<float> s_v_float = {0.0, 0.00001, 0.05, 0.1, 1.0, 10.0, 10000.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 37: {
            string f = "cpu_operator_cost";
            vector<float> s_v_float = {0.0, 0.00001, 0.05, 0.1, 1.0, 10.0, 10000.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 38: {
            string f = "parallel_setup_cost";
            long long s_int = get_rand_long_long(INT_MAX);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 39: {
            string f = "parallel_tuple_cost";
            long long s_int = get_rand_long_long(INT_MAX);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 40: {
            string f = "min_parallel_table_scan_size";
            int s_int = get_rand_int(715827882);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 41: {
            string f = "min_parallel_index_scan_size";
            int s_int = get_rand_int(715827882);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 42: {
            string f = "min_parallel_index_scan_size";
            int s_int = get_rand_int(INT_MAX);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 43: {
            string f = "effective_cache_size";
            int s_int = get_rand_int(INT_MAX);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 44: {
            string f = "jit_above_cost";
            vector<long long> s_v_int = {0, INT_MAX};
            long long s_int = vector_rand_ele(s_v_int);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 45: {
            string f = "jit_inline_above_cost";
            vector<long long> s_v_int = {0, INT_MAX};
            long long s_int = vector_rand_ele(s_v_int);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 46: {
            string f = "jit_optimize_above_cost";
            vector<long long> s_v_int = {0, INT_MAX};
            long long s_int = vector_rand_ele(s_v_int);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 47: {
            string f = "geqo";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 48: {
            string f = "geqo_threshold";
            int s_int = get_rand_int(2, 2147483647);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 49: {
            string f = "geqo_effort";
            int s_int = get_rand_int(1, 10);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 50: {
            string f = "geqo_pool_size";
            int s_int = get_rand_int(0, 2147483647);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 51: {
            string f = "geqo_generations";
            int s_int = get_rand_int(0, 2147483647);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 52: {
            string f = "geqo_generations";
            int s_int = get_rand_int(0, 2147483647);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 53: {
            string f = "geqo_selection_bias";
            vector<float> s_v_float = {1.5, 1.8, 2.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 54: {
            string f = "geqo_selection_bias";
            vector<float> s_v_float = {1.5, 1.8, 2.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 55: {
            string f = "geqo_seed";
            vector<float> s_v_float = {0, 0.5, 1.0};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 56: {
            string f = "default_statistics_target";
            int s_int = get_rand_int(1, 10000);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 57: {
            string f = "constraint_exclusion";
            vector<string> s_v_str = {"on", "off", "partition"};
            string s = vector_rand_ele(s_v_str);
            return make_pair(f, s);
        }
        case 58: {
            string f = "cursor_tuple_fraction";
            vector<float> s_v_float = {0.0, 0.1, 0.000001, 1.0, 0.5, 0.9999999};
            float s_float = vector_rand_ele(s_v_float);
            string s = to_string(s_float);
            return make_pair(f, s);
        }
        case 59: {
            string f = "from_collapse_limit";
            int s_int = get_rand_int(1, INT_MAX);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 60: {
            string f = "jit";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 61: {
            string f = "join_collapse_limit";
            int s_int = get_rand_int(1, INT_MAX);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 62: {
            string f = "parallel_leader_participation";
            int s_int = get_rand_int(2);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        case 63: {
            string f = "force_parallel_mode";
            vector<string> s_v_str = {"off", "on", "regress"};
            string s = vector_rand_ele(s_v_str);
            return make_pair(f, s);
        }
        case 64: {
            string f = "plan_cache_mode";
            vector<string> s_v_str = {"auto", "force_generic_plan", "force_custom_plan"};
            string s = vector_rand_ele(s_v_str);
            return make_pair(f, s);
        }
        case 65: {
            string f = "vacuum_freeze_min_age";
            vector<long long> s_v_int = {0, 5, 10, 100, 500, 1000000000};
            long long s_int = vector_rand_ele(s_v_int);
            string s = to_string(s_int);
            return make_pair(f, s);
        }
        default: {
            assert(false && "Fatal ERROR: Find unknown type inside: get_rel_option_set_configuration_options. \n ");
        }
    }
}

pair<string, string> RelOptionGenerator::get_rel_option_alter_attribute() {
    int cur_choice = get_rand_int(2);

    switch(cur_choice) {
        case 0: {
            string f = "n_distinct_inherited";
            vector<string> s_v_str = { "-1", "-0.8", "-0.5", "-0.2", "-0.1", "-0.0001", "0","0.0001", "0.1", "1" };
            string s = vector_rand_ele(s_v_str);
            return make_pair(f, s);
        }
        case 1: {
            string f = "n_distinct";
            vector<string> s_v_str = { "-1", "-0.8", "-0.5", "-0.2", "-0.1", "-0.0001", "0","0.0001", "0.1", "1" };
            string s = vector_rand_ele(s_v_str);
            return make_pair(f, s);
        }
        default: {
            assert(false && "Fatal ERROR: Find unknown type inside: get_rel_option_alter_attribute. \n ");
        }
    }

}
