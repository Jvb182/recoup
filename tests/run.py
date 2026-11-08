from pathlib import Path
import os
from lupa.lua51 import LuaRuntime

os.chdir(Path(__file__).resolve().parents[1])
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(Path('tests/spec.lua').read_text(encoding='utf-8'))
