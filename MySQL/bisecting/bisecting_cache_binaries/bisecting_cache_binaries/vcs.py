from distutils.version import LooseVersion
from typing import List

from constants import *
import git
import utils
import subprocess

_all_commits_hexsha = []
_all_sorted_tags = []
_all_commits_from_tags = []


def get_first_commit():
    cmd = 'git log --no-pager --pretty="%H" --reverse | head -1'
    commit, _, _ = utils.execute_command(cmd, cwd=MYSQL_ROOT)
    return commit.strip()


def get_commits_between_tags(left_tag, right_tag):
    cmd = f'git --no-pager log --pretty="%H" {left_tag}...{right_tag}'
    commits, _, _ = utils.execute_command(cmd, cwd=MYSQL_ROOT)
    commits = commits.splitlines()
    commits = list(map(lambda c: c.strip(), commits))
    return commits


def get_all_commits_hexsha():
    global _all_commits_hexsha

#    if MYSQL_SORTED_COMMITS.exists():
#        _all_commits_hexsha = utils.json_load(MYSQL_SORTED_COMMITS)
#        return _all_commits_hexsha

    if not _all_commits_hexsha:
        cmd = 'git checkout 8.0'
        utils.execute_command(cmd, cwd=MYSQL_ROOT)
        cmd = 'git --no-pager log --pretty="%H"'
        commits, _, _ = utils.execute_command(cmd, cwd=MYSQL_ROOT)
        commits = [commit.strip() for commit in commits.splitlines()]
        _all_commits_hexsha = commits

#        utils.json_dump(_all_commits_hexsha, MYSQL_SORTED_COMMITS)

    return _all_commits_hexsha


def get_all_sorted_tags():
    global _all_sorted_tags

    if not _all_sorted_tags:
        repo = git.Repo(MYSQL_ROOT)
                
        _all_tagrefs = [tagref for tagref in repo.tags if "cluster" not in tagref.name and "ndb" not in tagref.name]
        _all_sorted_tags = [
            tagref
            for tagref in sorted(
                _all_tagrefs, key=lambda tagref: LooseVersion(str(tagref.name))
            )
        ]

        _all_sorted_tags = [str(x.name) for x in _all_sorted_tags]
        _all_sorted_tags.reverse()

        """
        _all_sorted_tags = list(
            filter(
                lambda t: LooseVersion(t.name) >= LooseVersion("REL_10_0"),
                _all_sorted_tags,
            )
        )
        """
        # _all_sorted_tags = _all_sorted_tags[-100:]

    return _all_sorted_tags

def get_commit_from_tag(tag_str: str):
    commit = ""
    try:
        commit = subprocess.check_output( ['git', 'rev-parse', '--short', tag_str], cwd=MYSQL_ROOT ).decode().strip()
        #logger.debug("From tag: %s, getting commit: %s." % (tag_str, commit) )
        return commit
    except subprocess.CalledProcessError:
        commit = None
        #logger.debug("From tag: %s, getting commit: None." % (tag_str) )
        return None
    return None


def get_all_commits_from_tags():
    global _all_sorted_tags
    global _all_commits_from_tags

    if not _all_sorted_tags:
        get_all_sorted_tags()

    _all_commits_from_tags = [get_commit_from_tag(x) for x in _all_sorted_tags]
    return _all_commits_from_tags
    
