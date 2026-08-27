export default async function handler(req,res){
  const repo=String(req.query.repo||'').trim();
  const branch=String(req.query.branch||'main').trim();
  if(!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo)) return res.status(400).json({error:'Use owner/repository.'});
  const headers={Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'Watch-Dino-Viewer-Editor'};
  if(process.env.GITHUB_TOKEN) headers.Authorization=`Bearer ${process.env.GITHUB_TOKEN}`;
  try{
    const ref=await fetch(`https://api.github.com/repos/${repo}/git/ref/heads/${encodeURIComponent(branch)}`,{headers});
    if(!ref.ok) return res.status(ref.status).json({error:ref.status===404?'Repository or branch not found, or GITHUB_TOKEN cannot access it.':`GitHub ref request failed (${ref.status})`});
    const refJson=await ref.json();
    const commit=await fetch(`https://api.github.com/repos/${repo}/git/commits/${refJson.object.sha}`,{headers});
    if(!commit.ok) return res.status(commit.status).json({error:'Could not read branch commit.'});
    const commitJson=await commit.json();
    const tree=await fetch(`https://api.github.com/repos/${repo}/git/trees/${commitJson.tree.sha}?recursive=1`,{headers});
    if(!tree.ok) return res.status(tree.status).json({error:'Could not read repository tree.'});
    const treeJson=await tree.json();
    const files=(treeJson.tree||[]).filter(x=>x.type==='blob'&&/\.html?$/i.test(x.path||'')).map(x=>x.path).sort();
    res.status(200).json({repo,branch,files});
  }catch(e){res.status(500).json({error:e?.message||'GitHub request failed.'});}
}
