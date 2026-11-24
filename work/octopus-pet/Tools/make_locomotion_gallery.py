from pathlib import Path
import html, json, shutil, subprocess

project = Path(__file__).resolve().parents[1]
workspace = project.parents[1]
source = workspace/'output/locomotion-v06/previews'
root = workspace/'output/pet-collection-20/locomotion'
root.mkdir(exist_ok=True)
skins = [{'id':'original','name':'奶芋团子 · 章鱼全皮肤'}]+[s for s in json.loads((project/'Assets/Skins/skins.json').read_text()) if s.get('kind')]
checks=[]
for s in skins:
    name=s['id']
    p = subprocess.run(['ffprobe','-v','error','-select_streams','v:0','-count_frames','-show_entries','stream=width,height,nb_read_frames,r_frame_rate,duration','-of','json',str(source/f'{name}.mp4')],capture_output=True,text=True,check=True)
    stream=json.loads(p.stdout)['streams'][0]
    assert int(stream['nb_read_frames'])==270 and stream['r_frame_rate']=='30/1' and stream['width']==960 and stream['height']==540
    checks.append({'id':name,**stream})
    shutil.copy2(source/f'{name}.mp4',root/f'{name}.mp4')
    shutil.copy2(source/f'{name}-0-0.png',root/f'{name}.png')
shutil.copy2(project/'BoundaryInteractionPlan.txt',root/'plan.txt')
(root/'media-checks.json').write_text(json.dumps({'passed':True,'clips':checks},ensure_ascii=False,indent=2))
options=''.join(f'<option value="{s["id"]}" {"selected" if s["id"]=="chameleon" else ""}>{html.escape(s["name"])}</option>' for s in skins)
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>奶芋与朋友们 · 动作预览</title>
<style>*{box-sizing:border-box}body{margin:0;background:#f9f5fc;color:#51405e;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}main{max-width:1020px;margin:auto;padding:32px 24px}a{color:#78568c}h1{font-size:clamp(28px,5vw,44px);margin:24px 0 12px}p{line-height:1.8;color:#796486}label{display:flex;gap:12px;align-items:center;margin:22px 0}select,button{font:inherit;color:inherit;background:white;border:1px solid #d8c6e3;border-radius:12px;padding:11px 16px}select{max-width:75%}button{cursor:pointer}button:hover{background:#eadff2}nav{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}video{width:100%;display:block;aspect-ratio:16/9;background:#faf6fc;border:1px solid #e1d3eb;border-radius:16px}aside{padding:18px 22px;margin:24px 0;border-radius:16px;background:#eee4f5;line-height:1.9}footer{font-size:13px;line-height:1.7;color:#8c7897}:focus-visible{outline:3px solid #b48acb;outline-offset:3px}@media(max-width:500px){main{padding:22px 14px}button{font-size:13px;padding:10px}aside{padding:15px}}</style>
<main><a href="../index.html">← 角色图册</a><h1>看看它们怎么走。</h1><p>小爪子交替落地，触手轮流撑起身体。想安静陪你打字时，就让它留在右下角。</p>
<label for="pet">选择角色 <select id="pet">__OPTIONS__</select></label>
<video id="motion" controls playsinline preload="metadata" poster="chameleon.png" src="chameleon.mp4" aria-label="桌宠行走、攀爬与关闭后的待机预览"></video>
<nav aria-label="跳到视频片段"><button data-time="0">看行走 · 0 秒</button><button data-time="3">看攀爬 / 游动 · 3 秒</button><button data-time="6">看关闭后 · 6 秒</button></nav>
<aside><strong>随时关闭行走与攀爬</strong><br>菜单栏 🐙 → 屏幕边框互动 → 取消勾选「行走与攀爬动画」。<br>打字、鼠标点击、送字母和呼吸照常保留。重启、换角色、换屏幕后仍会记住设置。</aside>
<footer>视频左侧为实际角色，右侧用落脚点辅助观察：绿色表示支撑，橙色表示抬起。三段演示由桌宠真实渲染代码逐帧导出，预览不会改变桌宠设置。<br><a href="plan.txt">逐角色动作与参考资料</a></footer></main>
<script>const pet=document.getElementById('pet'),motion=document.getElementById('motion');pet.onchange=()=>{motion.pause();motion.poster=pet.value+'.png';motion.src=pet.value+'.mp4';motion.load()};document.querySelectorAll('[data-time]').forEach(button=>button.onclick=()=>{motion.currentTime=Number(button.dataset.time);motion.play().catch(()=>{})});</script></html>'''
(root/'index.html').write_text(page.replace('__OPTIONS__',options))
print('11 clips verified: 270 frames, 30 fps, 960 × 540 each')
