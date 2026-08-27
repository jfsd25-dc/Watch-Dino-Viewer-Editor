export default async function handler(req,res){
  const repo=String(req.query.repo||'').trim();
  const branch=String(req.query.branch||'main').trim();
  const path=String(req.query.path||'').trim();
  if(!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo)) return res.status(400).json({error:'Use owner/repository.'});
  if(!path||!/\.html?$/i.test(path)) return res.status(400).json({error:'Choose an HTML file.'});
  const headers={Accept:'application/vnd.github.raw+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'Watch-Dino-Viewer-Editor'};
  if(process.env.GITHUB_TOKEN) headers.Authorization=`Bearer ${process.env.GITHUB_TOKEN}`;
  try{
    const url=`https://api.github.com/repos/${repo}/contents/${path.split('/').map(encodeURIComponent).join('/')}?ref=${encodeURIComponent(branch)}`;
    const r=await fetch(url,{headers});
    if(!r.ok) return res.status(r.status).json({error:r.status===404?'HTML file not found, or GITHUB_TOKEN cannot access this private repository.':`GitHub file request failed (${r.status})`});
    res.status(200).json({repo,branch,path,content:await r.text()});
  }catch(e){res.status(500).json({error:e?.message||'GitHub file request failed.'});}
}
