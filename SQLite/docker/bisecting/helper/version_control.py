from logging import log
from git.objects import commit
from git import Repo
import os
import shutil
import subprocess

from bi_config import *
from helper.data_struct import log_out_line


class VerCon:

    all_commits_hexsha = []
    all_tags = []

    @classmethod
    def get_all_commits(cls, repo: Repo):
        if len(cls.all_commits_hexsha) != 0 or len(cls.all_tags) != 0:
            return cls.all_commits_hexsha, cls.all_tags

        cls._checkout_commit("master")

        all_commits = repo.iter_commits()
        for commit in all_commits:
            cls.all_commits_hexsha.append(commit.hexsha)
        cls.all_commits_hexsha.reverse()

        if END_COMMIT_ID != "":
            end_index = cls.all_commits_hexsha.index(END_COMMIT_ID)
            if end_index < len(cls.all_commits_hexsha):
                cls.all_commits_hexsha = cls.all_commits_hexsha[:end_index+1]
        if BEGIN_COMMIT_ID != "":
            begin_index = cls.all_commits_hexsha.index(BEGIN_COMMIT_ID)
            cls.all_commits_hexsha = cls.all_commits_hexsha[begin_index:]

        all_tags = sorted(repo.tags, key=lambda t: t.commit.committed_date)
        cls.all_tags = []
        for tag in all_tags:
            if tag.commit.hexsha in cls.all_commits_hexsha:
                cls.all_tags.append(tag)
        return cls.all_commits_hexsha, cls.all_tags

    @staticmethod
    def _checkout_commit(hexsha: str):
        os.chdir(SQLITE_DIR)
        with open(os.devnull, "wb") as devnull:
            subprocess.check_call(
                ["git", "checkout", hexsha, "--force"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.STDOUT,
            )
            log_out_line("Checkout commit: %s completed. " % (hexsha))

    @staticmethod
    def _compile_sqlite_binary(CACHED_INSTALL_DEST_DIR: str) -> bool:
        if os.path.isdir(CACHED_INSTALL_DEST_DIR):
            shutil.rmtree(CACHED_INSTALL_DEST_DIR)
        os.mkdir(CACHED_INSTALL_DEST_DIR)
        os.chdir(CACHED_INSTALL_DEST_DIR)
        with open(os.devnull, "wb") as devnull:
            result = subprocess.getstatusoutput("chmod +x ../../configure")
            if result[0] != 0:
                log_out_line("Compilation failed. Reason: %s. \n" % (result[1]))
             
            result = subprocess.getstatusoutput("../../configure  --enable-fts5 --enable-debug")
            if result[0] != 0:
                log_out_line("Compilation failed. Reason: %s. \n" % (result[1]))
                # If --enable-fts5 is not available, then we try the normal configure instead. 
                result = subprocess.getstatusoutput("../../configure")
                if result[0] != 0:
                    log_out_line("Compilation failed. Reason: %s. \n" % (result[1]))
                    return 1

            result = subprocess.getstatusoutput("make -j" + str(COMPILE_THREAD_COUNT) + " && strip sqlite3")
            if result[0] != 0:
                log_out_line("Compilation failed. Reason: %s. \n" % (result[1]))
                return 1
        log_out_line("Compilation completed. ")
        
        # Remove all other intermediate files, keep only the sqlite3 binary.
        for cur_sub_file in os.listdir(os.getcwd()):
            if cur_sub_file == "sqlite3":
                continue
            cur_file = os.path.join(os.getcwd(), cur_sub_file)
            if os.path.isdir(cur_file):
                shutil.rmtree(cur_file)
            else:
                os.remove(cur_file)

        log_out_line("All intermediate files removed. Only stripped SQLite3 binary are kept. ")

        return 0

    @classmethod
    def setup_SQLITE_with_commit(cls, hexsha: str):
        """
        Given the SQLite commit ID, check out the commit and compile the SQLite source code.
        If succeed, return the SQLite binary directory (not included the binary name) str;
        if failed, return empty str.
        """
        #log_out_line("Setting up SQLite3 with commitID: %s. \n" % (hexsha))
        if not os.path.isdir(SQLITE_BLD_DIR):
            os.mkdir(SQLITE_BLD_DIR)

        # INSTLL_DEST_DIR is not from the config file. It is being generated and immediately return in this function.
        INSTALL_DEST_DIR = os.path.join(SQLITE_BLD_DIR, hexsha)
        if not os.path.isdir(INSTALL_DEST_DIR):  # Not precompiled.
            cls._checkout_commit(hexsha=hexsha)
            result = cls._compile_sqlite_binary(
                CACHED_INSTALL_DEST_DIR=INSTALL_DEST_DIR
            )
            if result != 0:
                return ""  # Compile failed.
        elif not os.path.isfile(
            os.path.join(INSTALL_DEST_DIR, "sqlite3")
        ):  # Probably not compiled completely.
            log_out_line(
                "\n\n\nWarning: For commit: %s, installed dir exists, but sqlite3 is not compiled probably. \n\n\n"
                % (hexsha)
            )
            cls._checkout_commit(hexsha=hexsha)
            result = cls._compile_sqlite_binary(
                CACHED_INSTALL_DEST_DIR=INSTALL_DEST_DIR
            )
            if result != 0:
                return ""  # Compile failed.
        if os.path.isfile(
            os.path.join(INSTALL_DEST_DIR, "sqlite3")
        ):  # Compile successfully.
            return INSTALL_DEST_DIR
        else:  # Compile failed.
            return ""
