import os
import shutil
import subprocess
import atexit

from bi_config import *


class Fuzzer:
    all_fuzzing_instances_list = []

    @classmethod
    def setup_and_run_fuzzing(cls, oracle_str: str):
        os.chdir(FUZZING_ROOT_DIR)
        for i in range(CORE_ID_BEGIN, CORE_ID_BEGIN + MAX_FUZZING_INSTANCE):
            try:
                shutil.rmtree(os.path.join(FUZZING_ROOT_DIR, "fuzz_root_" + str(i)))
            except:
                print("Not able to delete the library. \n")
                pass

        for i in range(CORE_ID_BEGIN, CORE_ID_BEGIN + MAX_FUZZING_INSTANCE):
            shutil.copytree(
                os.path.join(FUZZING_ROOT_DIR, "fuzz_root"),
                os.path.join(FUZZING_ROOT_DIR, "fuzz_root_" + str(i)),
            )
            os.chdir(os.path.join(FUZZING_ROOT_DIR, "fuzz_root_" + str(i)))
            fuzzing_command = (
                FUZZING_COMMAND
                + " -c "
                + str(i)
                + " -O "
                + oracle_str
                + " -- "
                + SQLITE_FUZZING_BINARY_PATH
                + " &"
            )
            p = subprocess.Popen(
                [fuzzing_command],
                cwd=os.path.join(FUZZING_ROOT_DIR, "fuzz_root_" + str(i)),
                shell=True,
                stderr=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
            )

            cls.all_fuzzing_instances_list.append(p)
        atexit.register(cls.exit_handler)
        os.chdir(
            os.path.join(FUZZING_ROOT_DIR, "Bug_Analysis")
        )  # Change back to original workdir in case of errors.

    @classmethod
    def exit_handler(cls):
        for fuzzing_instance in cls.all_fuzzing_instances_list:
            fuzzing_instance.kill()
