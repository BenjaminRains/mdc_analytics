from contextlib import redirect_stdout
from io import StringIO

class ValidationReportWriter:
    def __init__(self, report_path):
        self.report_path = report_path
        self.sections = {}
        
    def capture_section(self, section_name):
        def decorator(func):
            def wrapper(*args, **kwargs):
                output = StringIO()
                with redirect_stdout(output):
                    result = func(*args, **kwargs)
                self.sections[section_name] = output.getvalue()
                return result
            return wrapper
        return decorator
    
    def write_report(self):
        with open(self.report_path, 'w', encoding='utf-8') as f:
            f.write("# Insurance Claim Validation Analysis 2024\n\n")
            for section, content in self.sections.items():
                f.write(f"## {section}\n```\n{content}\n```\n\n")



"""
also consider using IPython's capture_output context manager to capture output from functions

from IPython.display import capture_output

def capture_analysis(func):
    with capture_output() as c:
        func()
    return c.outputs

    Handling Different Output Types:
If your functions might produce outputs in forms other than standard text 
(such as rich display outputs in Jupyter), consider whether you need to handle these 
differently. You mentioned IPython.display.capture_output in your snippet—this tool is 
useful in Jupyter notebooks for capturing richer outputs. Decide which method fits your 
needs best or even combine them if necessary.

Error Handling and Cleanup:
While the context manager helps ensure stdout is restored on error, you might also want to 
capture error messages (if they are printed) so they’re included in your report. This can be 
useful for debugging or validation reports.

Combining Decorators:
Your separate capture_analysis function using IPython’s capture_output is another valid 
approach. You can choose to use one method or even design your class to support both 
depending on the environment (e.g., standard Python script vs. Jupyter Notebook).

"""