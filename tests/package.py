"""Build the installable addon and its legacy settings loader."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import re

root = Path(__file__).resolve().parents[1]
version = re.search(r'^## Version: (.+)$', (root/'Recoup.toc').read_text(), re.M).group(1)
(root/'dist').mkdir(exist_ok=True)
output = root/'dist'/f'Recoup-{version}.zip'
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for name in ['Recoup.toc', 'Ranking.lua', 'Recoup.lua', 'Bindings.xml', 'README.md']:
        archive.write(root/name, 'Recoup/'+name)
    for name in ['SnackBar.toc', 'Bindings.xml']:
        archive.write(root/'compat'/'SnackBar'/name, 'SnackBar/'+name)
with ZipFile(output) as archive:
    assert archive.testzip() is None
print(output)
