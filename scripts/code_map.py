import os, json
ROOT = os.getcwd()
def list_tree(base):
  out = []
  for dirpath, dirnames, filenames in os.walk(base):
    dirnames[:] = [d for d in dirnames if not d.startswith('.') and d not in ('node_modules','build','.gradle','__pycache__')]
    for f in filenames:
      if f.startswith('.'): continue
      out.append(os.path.relpath(os.path.join(dirpath,f), ROOT))
  return out
index = {}
for p in ['services','apps','packages']:
  if os.path.isdir(p):
    index[p] = list_tree(p)
os.makedirs('docs/reference', exist_ok=True)
with open('docs/reference/code-map.json','w',encoding='utf-8') as f: json.dump(index, f, ensure_ascii=False, indent=2)
with open('docs/reference/code-map.md','w',encoding='utf-8') as f:
  f.write("# 代码地图（自动生成）\n")
  for k, paths in index.items():
    f.write(f"\n## {k}（{len(paths)} 个文件）\n")
    for x in paths[:200]: f.write(f"- {x}\n")
print("[map] 生成完成")
