from pathlib import Path
import json, html, shutil

project = Path(__file__).resolve().parents[1]
root = project.parents[1] / 'output/pet-collection-20/boundary'
skins = [{'id':'original','name':'奶芋团子 · 章鱼全皮肤'}] + [s for s in json.loads((project/'Assets/Skins/skins.json').read_text()) if s.get('kind')]
labels = ['从边框外进来','沿底边走动','往右边框上爬','角色专属动作','落地 / 回到角落','扒边探头送字']
for skin in skins:
    for i in range(6):
        assert (root/f"{skin['id']}-{i}.png").is_file()
cards = ''.join(f'<option value="{s["id"]}">{html.escape(s["name"])}</option>' for s in skins)
buttons = ''.join(f'<button data-pose="{i}" aria-pressed="false">{label}</button>' for i,label in enumerate(labels))
page = '''<!DOCTYPE html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>桌宠的边框小剧场</title><style>
*{box-sizing:border-box}body{margin:0;background:#f8f4fa;color:#51405e;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}main{max-width:1180px;margin:auto;padding:36px 24px}h1{font-size:clamp(28px,5vw,46px);margin:15px 0}p{line-height:1.8;color:#8a7598}a{color:#8864a1}nav{display:flex;gap:9px;flex-wrap:wrap;margin:20px 0}button,select{font:inherit;background:#fff;color:#695075;border:1px solid #d9cce3;border-radius:12px;padding:11px 14px}button{cursor:pointer}button[aria-pressed=true]{background:#86629c;color:#fff;border-color:#86629c}button:focus-visible,a:focus-visible,select:focus-visible{outline:3px solid #b798cf;outline-offset:3px}figure{margin:0;background:#fff;border:1px solid #e4d9ec;border-radius:18px;overflow:hidden}img{display:block;width:100%;height:auto;aspect-ratio:1.4}footer{margin-top:22px;font-size:14px;line-height:1.8}label{display:flex;align-items:center;gap:12px}select{max-width:100%}@media(max-width:500px){main{padding:24px 14px}nav{gap:6px}button{font-size:12px;padding:9px}}
</style><main><a href="../index.html">← 回到角色图册</a><h1>屏幕边缘，是它们的小游乐场。</h1>
<p>从边框外探进来，沿着底边走一走，再爬到侧面。你打字或点击时，它会继续移动，同时伸出触手或舌头回应。</p>
<label>选择角色 <select id="pet">__OPTIONS__</select></label><nav aria-label="动作关键帧">__BUTTONS__</nav>
<figure><img id="scene" src="original-3.png" alt="奶芋团子拍击屏幕边缘"></figure>
<footer>这里展示每个动作的关键帧。在桌面上打开 🐙 → 屏幕边框互动 → 现在展示边框动作，可观看连续动画。<br>
“扒着右边框探头送字”会停留在侧边；“固定在右下角”可关闭巡游。<br><a href="plan.txt">查看逐角色动作计划</a></footer>
<script>let pose=3;const pet=document.getElementById('pet'),scene=document.getElementById('scene');
function show(){scene.src=pet.value+'-'+pose+'.png';scene.alt=pet.selectedOptions[0].textContent+' · '+document.querySelector('[data-pose="'+pose+'"]').textContent;document.querySelectorAll('[data-pose]').forEach(b=>b.setAttribute('aria-pressed',Number(b.dataset.pose)===pose))}
document.querySelectorAll('[data-pose]').forEach(b=>b.onclick=()=>{pose=Number(b.dataset.pose);show()});pet.onchange=show;show();</script></main></html>'''
(root/'index.html').write_text(page.replace('__OPTIONS__',cards).replace('__BUTTONS__',buttons))
shutil.copy2(project/'BoundaryInteractionPlan.txt',root/'plan.txt')
print('Boundary gallery ready: 11 character forms, 66 real renderer snapshots')
