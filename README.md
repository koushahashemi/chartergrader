# Charter Grader

Offline Windows grading assistant for Part 2 of the Greenify project charter assignment. Uses a local Ollama model; student submissions are not uploaded.

## Use on Windows

1. Download this repository as a ZIP and extract it.
2. Run `Setup.bat` once while online to install Python, Ollama, and the local model.
3. Disconnect the internet and run `Start Grader.bat`.
4. Select a student DOCX, review the suggested scores and feedback, then export.

See [READ ME FIRST.txt](READ%20ME%20FIRST.txt) for requirements, privacy details, and limitations. Instructor review is required. The seven criteria total 21 marks; the separate 50% template penalty requires confirmation.

## Validation

Run `python -m unittest -v test_grader`. Seven automated tests passed in Linux with fictional documents and mocked model responses. Windows installation, the visual interface, and actual local-model grading have not yet been verified.

## Included materials

`resources/` contains the instructor-provided scenario references, Part 2 instructions, rubric, and official blank template required by the app. No student submissions are included. Do not redistribute course materials beyond permitted use.
