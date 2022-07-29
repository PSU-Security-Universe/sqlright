import os


def format():
    """Format changed code."""
    output = os.popen("git diff --name-only --relative HEAD").read()

    file_paths = output.splitlines()
    python_file_paths = [f for f in file_paths if f.endswith(".py") and "venv" not in f]
    cpp_file_paths = [f for f in file_paths if f.endswith(".cpp") or f.endswith(".h")]

    for file_path in python_file_paths:
        os.system("black " + file_path)

    for file_path in cpp_file_paths:
        os.system("clang-format -i " + file_path)


if __name__ == "__main__":
    format()
