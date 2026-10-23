from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[2]
strings=json.loads((root/'ShunTools/Resources/Localizable.xcstrings').read_text())['strings']
codes=['zh-Hans','zh-Hant','en','ja','ko','fr','de','es','pt-BR']
keys=set()
for p in (root/'ShunTools').rglob('*.swift'):
 keys.update(x.replace('\\n','\n') for x in re.findall(r'L\("((?:[^"\\]|\\.)*)"',p.read_text()))
for key in keys:
 assert key in strings, f'Missing key: {key}'
 for code in codes:
  value=strings[key]['localizations'][code]['stringUnit']['value']
  assert value, (key,code)
  assert sorted(re.findall(r'\{\d+\}',key))==sorted(re.findall(r'\{\d+\}',value)),(key,code)
print(f'{len(keys)} active strings complete across {len(codes)} languages; interpolation placeholders match.')
