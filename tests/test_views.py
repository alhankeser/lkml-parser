import os
import json
import lkml
import time
import pytest
import subprocess


VIEW_PATH = os.path.join("tests", "input_files", "views")
VIEW_FILES = [
    filepath for filepath in os.listdir(VIEW_PATH) if ".view.lkml" in filepath
]
OUTPUT_PATH = os.path.join("tests", "output_files")
ZLKML_OUTPUT_PATH = os.path.join(OUTPUT_PATH, "zlkml")
LKML_OUTPUT_PATH = os.path.join(OUTPUT_PATH, "lkml")


def get_filepath(filename: str) -> str:
    filepath = os.path.join(VIEW_PATH, filename)
    return filepath


def test_has_view_files():
    assert len(VIEW_PATH) > 0


# def test_can_build():
#     result = subprocess.run(
#         ["zig", "build-exe", "./main.zig", "-O", "ReleaseFast"],
#         capture_output=True,
#         text=True,
#     )
#     assert result.returncode == 0


@pytest.mark.parametrize("view_file", VIEW_FILES)
def test_can_parse_view_files(view_file):
    print(view_file)
    filepath = get_filepath(view_file)
    parsed = parse_zlkml(filepath)
    assert "views" in parsed


def parse_zlkml(filepath) -> dict:
    parsed = subprocess.getoutput(f"./main {filepath}")
    parsed = json.loads(parsed)
    return parsed


def parse_lkml(filepath) -> dict:
    with open(filepath) as f:
        parsed = lkml.load(f.read())
    return parsed

@pytest.mark.parametrize("view_file", VIEW_FILES)
def test_zlkml_is_faster(view_file):
    filepath = get_filepath(view_file)
    zlkml_t1 = time.perf_counter()
    zlkml = parse_zlkml(filepath)
    zlkml_t2 = time.perf_counter()
    lkml_t1 = time.perf_counter()
    lkml = parse_lkml(filepath)
    lkml_t2 = time.perf_counter()
    zlkml_time = zlkml_t2-zlkml_t1
    lkml_time = lkml_t2-lkml_t1
    assert zlkml_time < lkml_time



@pytest.mark.parametrize("view_file", VIEW_FILES)
def test_matches_lkml_output(view_file):
    filepath = get_filepath(view_file)
    print(filepath)
    test = parse_zlkml(filepath)
    control = parse_lkml(filepath)
    json_filename = view_file.replace(".view.lkml", ".json")
    with open(os.path.join(ZLKML_OUTPUT_PATH, json_filename), "w") as f:
        f.write(json.dumps(test))
    with open(os.path.join(LKML_OUTPUT_PATH, json_filename), "w") as f:
        f.write(json.dumps(control))
    assert control == test
