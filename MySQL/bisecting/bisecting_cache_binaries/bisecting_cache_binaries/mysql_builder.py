from pathlib import Path
import constants
import utils
from loguru import logger
import subprocess
import os
import shutil

def checkout_and_clean_mysql_repo(hexsha: str):
    checkout_cmd = f"git checkout {hexsha} --force && git clean -xdf"
    utils.execute_command(checkout_cmd, cwd=constants.MYSQL_ROOT)

    logger.debug(f"Checkout commit completed: {hexsha}")

def compile_mysql_source(hexsha: str):
    BLD_PATH = os.path.join(constants.MYSQL_ROOT, "bld")
    boost_setup_command = "ln -s /home/mysql/boost_versions /home/mysql/mysql-server/boost"
    utils.execute_command(boost_setup_command, cwd=BLD_PATH)

    run_cmake = "CC=gcc-6 CXX=g++-6 cmake .. -DWITH_BOOST=../boost -DDOWNLOAD_BOOST=1 -DCMAKE_INSTALL_PREFIX=$(pwd)"
    utils.execute_command(run_cmake, cwd=BLD_PATH)

    run_make = "make install -j$(nproc)"
    utils.execute_command(run_make, cwd=BLD_PATH)

    compiled_program_path = os.path.join(BLD_PATH, "bin/mysqld")
    if os.path.isfile(compiled_program_path):
        is_success = True
    else:
        is_success = False

    if is_success:
        logger.debug("Compilation succeed: %s." % (hexsha))
    else:
        logger.warning("Failed to compile: %s" % (hexsha))

    return is_success

def copy_binaries (hexsha: str):
    # Setup the output folder. 
    cur_output_dir = os.path.join(constants.OUTPUT_DIR, hexsha)
    utils.execute_command("mkdir -p %s" % (cur_output_dir), cwd = constants.OUTPUT_DIR)


    if os.path.isfile("/home/mysql/mysql-server/bld/scripts/mysql_install_db"):
        # This is the old version of the code. Need several more folders to be copied. 
        utils.execute_command("strip /home/mysql/mysql-server/bld/bin/mysqld", cwd=cur_output_dir)
        utils.execute_command("strip /home/mysql/mysql-server/bld/bin/mysql", cwd=cur_output_dir)
        shutil.copytree("/home/mysql/mysql-server/bld/bin", os.path.join(cur_output_dir, "bin"))
        shutil.copytree("/home/mysql/mysql-server/bld/scripts", os.path.join(cur_output_dir, "scripts"))
        shutil.copytree("/home/mysql/mysql-server/bld/extra", os.path.join(cur_output_dir, "extra"))
        shutil.copytree("/home/mysql/mysql-server/bld/support-files", os.path.join(cur_output_dir, "support-files"))
        shutil.copytree("/home/mysql/mysql-server/bld/share", os.path.join(cur_output_dir, "share"))

        return True

    elif os.path.isfile("/home/mysql/mysql-server/bld/bin/mysqld"):
        cur_output_bin = os.path.join(cur_output_dir, "bin")
        utils.execute_command("mkdir -p %s" % (cur_output_bin), cwd = cur_output_dir)

        utils.execute_command("strip /home/mysql/mysql-server/bld/bin/mysqld", cwd=cur_output_dir)
        utils.execute_command("strip /home/mysql/mysql-server/bld/bin/mysql", cwd=cur_output_dir)
        shutil.copytree("/home/mysql/mysql-server/bld/bin", os.path.join(cur_output_dir, "bin"))
        shutil.copytree("/home/mysql/mysql-server/bld/scripts", os.path.join(cur_output_dir, "scripts"))
        if os.path.isfile("/home/mysql/mysql-server/bld/bin/mysql_ssl_rsa_setup"):
            shutil.copy("/home/mysql/mysql-server/bld/bin/mysql_ssl_rsa_setup", cur_output_bin)
        for lib_file in os.listdir("/home/mysql/mysql-server/bld/library_output_directory"):
            if "libprotobuf-lite" in lib_file:
                shutil.copy(os.path.join("/home/mysql/mysql-server/bld/library_output_directory", lib_file), cur_output_bin)

        # Slightly older version, such as MySQL 5.7. Copy a few more folders in advanced. 
        if os.path.isfile("/home/mysql/mysql-server/bld/sql/mysqld"):
            utils.execute_command("strip /home/mysql/mysql-server/bld/sql/mysqld", cwd=cur_output_bin)
            utils.execute_command("strip /home/mysql/mysql-server/bld/client/mysql", cwd=cur_output_bin)
            shutil.copytree("/home/mysql/mysql-server/bld/sql", os.path.join(cur_output_bin, "sql"))
            shutil.copytree("/home/mysql/mysql-server/bld/client", os.path.join(cur_output_bin, "client"))

        return True

    else:
        logger.error("The mysqld output file not found. Compilation Failed?")
        return False

    return True


def setup_mysql_commit(hexsha: str):

    # First of all, check whether the pre-compiled binary exists in the destination directory.
    if os.path.isdir(constants.OUTPUT_DIR):
        cur_output_dir = os.path.join(constants.OUTPUT_DIR, hexsha)
        if os.path.isdir(cur_output_dir):
            cur_output_binary = os.path.join(cur_output_dir, "bin/mysql")
            old_cur_output_binary = os.path.join(cur_output_dir, "bin/client/mysql")
            old_cur_output_binary_2 = os.path.join(cur_output_dir, "bin/bin/mysql")
            if os.path.isfile(cur_output_binary) or os.path.isfile(old_cur_output_binary) or os.path.isfile(old_cur_output_binary_2):
                # The precompiled version existed, skip compilation. 
                logger.debug("MySQL Version: %s existed. Skip compilation. " % (hexsha))
                is_success = True
                return is_success

            # output folder exists, but the bin subfolder is not. Recompile. 
            shutil.rmtree(cur_output_dir)
    else:
        print("FATEL ERROR: cannot find the output dir. ")


    logger.debug("Checkout and clean up MySQL root dir.")
    checkout_and_clean_mysql_repo(hexsha)
    utils.execute_command("mkdir -p bld", cwd=constants.MYSQL_ROOT)

    logger.debug("Compile MySQL root dir.")
    is_success = compile_mysql_source(hexsha)

    if not is_success:
        logger.warning("Failed to compile MySQL with commit %s directly." % (hexsha))
        return False

    # Copy the necessary files to the output repo. 
    is_success = copy_binaries(hexsha)

    if not is_success:
        logger.warning("Failed to copy binary MySQL with commit %s directly." % (hexsha))
        return False

    return is_success

