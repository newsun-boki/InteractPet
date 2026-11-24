from pathlib import Path
import json
import shutil
import html

project = Path(__file__).resolve().parents[1]
root = project.parents[1] / 'output' / 'pet-collection-20'
all_skins = json.loads((project / 'Assets/Skins/skins.json').read_text())
skins = [s for s in all_skins if not s.get('kind')]
characters = json.loads((root / 'originals/characters.json').read_text())
assert len(skins) == len(characters) == 10
cards = []
for i, skin in enumerate(skins, 1):
    cards.append(dict(number=i, id=skin['id'], name=skin['name'], group='octopus',
        tag='章鱼换装', status='已接入桌宠', color=skin['accent'],
        note=skin['note'], detail='八条触手轮流送字母；换肤时身体、触手、吸盘与字牌同步换色。',
        image=f"octopus/{skin['id']}.png", reach=f"octopus/{skin['id']}-reach.png"))
for i, character in enumerate(characters, 11):
    cards.append(dict(number=i, id=character['id'], name=character['name'], group='original',
        tag=character['kind'], status='已接入桌宠', color='#8c78b3',
        note=character['mechanic'], detail=character['mechanic'],
        image=f"characters/{character['id']}.png", reach=f"characters/{character['id']}-reach.png"))
for card in cards:
    assert (root / card['image']).is_file()
    if card['reach']:
        assert (root / card['reach']).is_file()
shutil.copy2(project / 'Assets/Skins/prompts.json', root / 'octopus/prompts.json')
(root / 'octopus/skins.json').write_text(json.dumps(skins, ensure_ascii=False, indent=2))
shutil.copy2(project / 'Assets/Skins/characters-prompts.json', root / 'characters/prompts.json')
(root / 'characters/skins.json').write_text(json.dumps([s for s in all_skins if s.get('kind') and s['id'] != 'five-kittens'], ensure_ascii=False, indent=2))
(root / 'collection.json').write_text(json.dumps(cards, ensure_ascii=False, indent=2))

template = r'''<!DOCTYPE html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>奶芋与朋友们 · 20 款桌宠图册</title>
<style>
:root{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;color:#493751;background:#faf7fa;--accent:#9272b6}*{box-sizing:border-box}body{margin:0}header,main,footer{max-width:1440px;margin:auto;padding:32px 32px}header{padding-top:58px;padding-bottom:22px}.eyebrow{color:#9b84ac;font-size:13px;letter-spacing:.16em}h1{font-size:clamp(30px,4vw,52px);margin:18px 0 14px;letter-spacing:-.04em}header p{max-width:800px;line-height:1.8;color:#88778d;margin:0}.tools{display:flex;gap:9px;align-items:center;flex-wrap:wrap;margin-top:26px}button,a{font:inherit}button{cursor:pointer}button,.pill{border:1px solid #e8dfee;background:#fff;border-radius:99px;color:#695571;padding:10px 17px;font-size:14px;text-decoration:none}button.active{background:#71528c;color:white;border-color:#71528c}button:hover,.pill:hover{border-color:#ae8fc9}button:focus-visible,a:focus-visible{outline:3px solid #b591d5;outline-offset:3px}.spacer{flex:1}main{padding-top:10px}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:22px}.card{background:#fff;border:1px solid #efe8f2;border-radius:24px;overflow:hidden;box-shadow:0 8px 24px #6e4b8510}.visual{display:block;position:relative;width:100%;border:0;border-radius:0;padding:0;aspect-ratio:1.14;background:linear-gradient(145deg,#fffaf7,#f5effa)}.visual img{width:100%;height:100%;object-fit:contain;padding:18px;transition:transform .2s}.visual:hover img{transform:translateY(-4px) scale(1.02)}.number{position:absolute;left:17px;top:14px;font-size:12px;font-weight:700;letter-spacing:.08em;color:#a895b6}.copy{padding:18px 20px 21px}.meta{display:flex;justify-content:space-between;align-items:center;font-size:11px;color:#a695ad;gap:8px}.tag{padding:4px 8px;border-radius:6px;background:#f7f1fb;color:#9474ab}.card h2{font-size:20px;margin:13px 0 9px}.card p{font-size:13px;line-height:1.75;color:#938299;margin:0;min-height:46px}.download{display:inline-block;font-size:12px;color:#9572b1;margin-top:12px;text-underline-offset:4px}footer{color:#9a899f;font-size:13px;line-height:1.8;padding-top:10px;padding-bottom:40px}dialog{border:1px solid #e7dceb;border-radius:26px;padding:22px;max-width:min(920px,95vw);width:920px;background:#fffcff;color:#493751}dialog::backdrop{background:#29203280;backdrop-filter:blur(8px)}.dialog-top{display:flex;align-items:center;justify-content:space-between;gap:16px}.dialog-top h2{margin:0;font-size:24px}.dialog-picture{margin-top:16px;border-radius:18px;height:min(61vh,640px);background:linear-gradient(135deg,#f8f0f9,#fff9ef);display:flex;align-items:center;justify-content:center}.dialog-picture img{max-width:100%;max-height:100%;object-fit:contain;padding:18px}.dialog-picture.dark{background:#28303b}.dialog-foot p{font-size:14px;color:#8f7b98;line-height:1.7}.dialog-foot .tools{margin-top:12px}button[hidden]{display:none}.empty{grid-column:1/-1;padding:60px;color:#9b84ac;text-align:center}@media(max-width:1100px){.grid{grid-template-columns:repeat(3,minmax(0,1fr))}}@media(max-width:760px){header,main,footer{padding-left:18px;padding-right:18px}.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.copy{padding:14px}.card h2{font-size:17px}.card p{font-size:12px}.meta{font-size:10px}.tools{gap:7px}.tools button,.pill{padding:9px 13px;font-size:12px}}@media(prefers-reduced-motion:reduce){.visual img{transition:none}}
</style>
<header><span class="eyebrow">TARO & FRIENDS / 20 CHARACTERS</span><h1>给桌面，多养几个小伙伴。</h1><p>奶芋小八爪有了 10 套新衣服，还有 10 位会搬字母的新朋友。全部已接入桌宠，各有自己的伸展动作。点开图片，可以看大图、伸手姿态或保存透明 PNG。</p><nav class="tools" aria-label="角色分类"><button class="active" data-filter="all">全部 20 款</button><button data-filter="octopus">章鱼皮肤 10 款</button><button data-filter="original">原创角色 10 款</button><span class="spacer"></span><a class="pill" href="five-kittens-tails/index.html">卷尾递字 · 尾巴小剧场</a><a class="pill" href="five-kittens-rig/index.html">五猫小队 · 骨骼与屏幕互动</a><a class="pill" href="five-kittens/index.html">五只小猫 · 一起摇摆</a><a class="pill" href="concurrent/index.html">边走边送字 · 新演示</a><a class="pill" href="locomotion/index.html">行走 / 攀爬动画预览</a><a class="pill" href="octopus-skins-preview.mp4">章鱼换肤动画</a><a class="pill" href="characters-preview.mp4">新角色送字动画</a></nav></header>
<main><div id="grid" class="grid"></div></main>
<footer>全部已接入 v0.9.0 桌宠，菜单栏 🐙 → 更换角色 / 皮肤。加上原版奶芋团子与五猫排排坐，共 22 个可选外观。<br>图册展示桌宠程序实际渲染；角色素材使用内置图片生成制作，提示词保存在各素材目录的 prompts.json。</footer>
<dialog id="detail"><div class="dialog-top"><h2 id="detail-title"></h2><button id="close" aria-label="关闭大图">关闭 ×</button></div><div class="dialog-picture" id="picture"><img id="large" alt=""></div><div class="dialog-foot"><p id="description"></p><div class="tools"><button id="pose">看伸手动作</button><button id="background">切换深色背景</button><a id="save" class="pill" download>保存这张 PNG</a></div></div></dialog>
<script>
const cards=__CARDS__;
const grid=document.getElementById('grid'),dialog=document.getElementById('detail');let current=null,reaching=false;
function show(filter='all'){
 grid.replaceChildren();
 cards.filter(c=>filter==='all'||c.group===filter).forEach(c=>{
  const card=document.createElement('article');card.className='card';
  const picture=document.createElement('button');picture.className='visual';picture.setAttribute('aria-label','查看'+c.name);picture.onclick=()=>openDetail(c);
  const num=document.createElement('span');num.className='number';num.textContent=String(c.number).padStart(2,'0');
  const image=document.createElement('img');image.src=c.image;image.alt=c.name;image.loading='lazy';picture.append(num,image);
  const copy=document.createElement('div');copy.className='copy';
  const meta=document.createElement('div');meta.className='meta';const tag=document.createElement('span');tag.className='tag';tag.textContent=c.tag;const status=document.createElement('span');status.textContent=c.status;meta.append(tag,status);
  const title=document.createElement('h2');title.textContent=c.name;const note=document.createElement('p');note.textContent=c.note;
  const download=document.createElement('a');download.className='download';download.href=c.image;download.download=c.id+'.png';download.textContent='透明 PNG ↗';
  copy.append(meta,title,note,download);card.append(picture,copy);grid.append(card);
 });
}
function setPicture(){const path=reaching&&current.reach?current.reach:current.image;document.getElementById('large').src=path;document.getElementById('large').alt=current.name;document.getElementById('save').href=path;document.getElementById('save').download=current.id+(reaching?'-reach':'')+'.png';document.getElementById('pose').textContent=reaching?'看待机造型':'看伸手动作'}
function openDetail(c){current=c;reaching=false;document.getElementById('detail-title').textContent=String(c.number).padStart(2,'0')+' · '+c.name;document.getElementById('description').textContent=c.detail;document.getElementById('pose').hidden=!c.reach;setPicture();dialog.showModal()}
document.querySelectorAll('[data-filter]').forEach(button=>button.onclick=()=>{document.querySelectorAll('[data-filter]').forEach(b=>b.classList.toggle('active',b===button));show(button.dataset.filter)});
document.getElementById('pose').onclick=()=>{reaching=!reaching;setPicture()};
document.getElementById('background').onclick=()=>{const dark=document.getElementById('picture').classList.toggle('dark');document.getElementById('background').textContent=dark?'切换浅色背景':'切换深色背景'};
document.getElementById('close').onclick=()=>dialog.close();dialog.onclick=e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close()}};show();
</script></html>'''
(root / 'index.html').write_text(template.replace('__CARDS__', json.dumps(cards, ensure_ascii=False).replace('</', '<\\/')))
notes = '''奶芋与朋友们 · 20 款桌宠图册

双击 index.html 查看全部 20 款。图片可放大，所有角色均可切换待机与伸展姿态，并有透明 PNG。

10 款章鱼皮肤
已接入 Taro Octopus v0.9.0：草莓奶冻、薄荷巧巧、抹茶团子、焦糖布丁、蜜桃乌龙、星河晚安、海盐珍珠、樱花糯米、南瓜小巫、雪顶棉花糖。原版奶芋团子额外保留。
菜单栏 🐙 → 更换角色 / 皮肤；选择会自动保存。触手、吸盘、脸部及字母牌配色一同切换。
octopus/ 目录为完整角色 PNG，带 -reach 的文件是伸手姿态；原始头部素材和配色在应用包的 Contents/Resources/Skins/。
octopus-skins-preview.mp4 为使用实际桌宠渲染代码导出的 25 秒演示，不代表所有应用都已兼容。

10 个其他原创角色
十款已全部接入程序，可与章鱼在同一个菜单切换，支持键盘、鼠标触发、动态表情、身体联动和字母递送。
史莱姆有两只软糖手；幽灵有两只长袖；变色龙有一条卷舌；盆栽有三条叶片藤蔓；云朵有一条三色彩虹滑道；水母有四条发光腕带；线团猫有一条编织长尾；蜘蛛有两条细丝吊篮；星星法师有两条星光飘带；机器人有两只弹簧手臂。
characters/ 是实际桌宠渲染的透明 PNG（包括待机与伸展姿态），characters-preview.mp4 是程序动画演示。originals/ 保留最初的原创设计图与动作说明，可用于后续美术调整。

v0.6 动作与开关
连续打字时，变色龙、云朵、线团猫会保留伸出的递送路径，并就地更新字母；停字后再淡出收回。
菜单栏 🐙 → 屏幕边框互动：行走与攀爬动画、现在展示边框动作、扒着右边框探头送字、固定在右下角。
行走与攀爬使用分关节动画：脚步交替支撑，触手/藤蔓轮流抓边，漂浮角色有软体起伏。打字和点击可以与行走、攀爬同时进行，不打断移动；伸出的触手随身体移动，收回时接回当前步态。取消勾选「行走与攀爬动画」可关闭全部巡游并固定在右下角，保留打字、点击、送字与呼吸；重启、换角色或换屏幕后仍记住设置。
locomotion/index.html 提供 11 段行走、攀爬/游动与关闭待机的 MP4；locomotion/plan.txt 是实现说明和参考资料。原有两段 MP4 保留为基础送字效果演示。

v0.7 五猫排排坐
新增五只小猫共同摇摆的成组角色，五只轮流伸爪递字，打字和点击不打断摇摆。菜单选择「五只小猫 · 排排坐」后，可单独关闭「五只小猫一起摇摆」，重启仍记住。该角色默认坐着陪伴；原有角色的巡游偏好保留。five-kittens/index.html 为 12 秒原生预览。加上原版奶芋团子，目前共 22 个外观。

v0.8 五猫骨骼与群体互动
五只猫分别绑定四肢 IK、头耳骨骼、脊柱和尾巴 spline。沿底边依次跟随；最右黑白猫起跳扒边、攀爬和抬爪探头，其他四只做抬头、抬爪与落地回应。屏幕边框互动菜单可关闭整套群体动作，并平滑回座；摇摆开关独立。打字和点击仍与群体动作并行。five-kittens-rig/index.html 为 30 秒原生动画和骨骼叠加预览。

v0.9 灵动尾巴
五猫从尾根伸出尾巴递字，末端以小卷尾托住字牌。待机有轻扫、问号卷尾、绕尾与甩尾；伸出有预摆和沿尾传播的波动，接触轻点，回收带余摆。尾巴小动作可独立关闭且重启保存，关闭后保留打字/点击递送。five-kittens-tails/index.html 包含放大尾巴动作与边走边攀爬边递字两段原生预览。

运行桌宠合集
适用于 Apple Silicon Mac。先退出正在运行的旧版，再打开此目录的 Taro Octopus.app。应用为本地构建；若 macOS 提示辅助功能授权，请按系统提示启用当前应用。新构建的本地签名发生变化时，旧的授权可能需要重新开启。
已有输入位置兼容性限制仍然存在，微信等场景没有因换肤而自动修复；可使用菜单里的演示模式先看换装动画。

素材由内置 image_gen 制作，完整角色由原生桌宠渲染器绘制。全部生成提示词已随素材保存。
'''
(root / '使用说明.txt').write_text(notes)
print(f'Gallery ready: {len(cards)} cards, 20 alternate reaching poses')
