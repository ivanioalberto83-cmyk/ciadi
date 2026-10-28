import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { PDFDocument, StandardFonts, rgb } from "https://esm.sh/pdf-lib@1.17.1";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"};
const money=(n:any)=>Number(n||0).toLocaleString("pt-AO",{minimumFractionDigits:2,maximumFractionDigits:2});
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 try{
  const auth=req.headers.get("Authorization"); if(!auth) throw new Error("Não autenticado");
  const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:auth}}});
  const {data:{user},error:ue}=await sb.auth.getUser(); if(ue||!user) throw new Error("Sessão inválida");
  const body=await req.json(); const id=body.documento_fiscal_id; const requested=body.tipo;
  if(!id) throw new Error("documento_fiscal_id obrigatório");
  const {data:d,error:de}=await sb.from("documentos_fiscais").select("*").eq("id",id).single(); if(de||!d) throw new Error("Documento não encontrado");
  const {data:perfil}=await sb.from("perfis").select("instituicao_id,role").eq("id",user.id).single();
  const roles=["super_admin","school_admin","accountant","principal","reception","staff"];
  if(!perfil || !roles.includes(perfil.role) || (perfil.role!=="super_admin" && perfil.instituicao_id!==d.instituicao_id)) throw new Error("Sem autorização");
  const {data:inst}=await sb.from("instituicao").select("*").eq("id",d.instituicao_id).single();
  const {data:linhas}=await sb.from("documentos_fiscais_linhas").select("*").eq("documento_id",id).order("created_at");
  const tipo=String(requested||d.tipo||"fatura").toLowerCase();
  const pdf=await PDFDocument.create(); let page=pdf.addPage([595,842]);
  const font=await pdf.embedFont(StandardFonts.Helvetica); const bold=await pdf.embedFont(StandardFonts.HelveticaBold);
  let y=790;
  const ensure=()=>{if(y<115){page=pdf.addPage([595,842]);y=790;}};
  const txt=(t:any,x=45,size=10,f=font)=>{ensure();page.drawText(String(t??""),{x,y,size,font:f,color:rgb(0.12,0.12,0.12)});y-=size+6;};
  const inline=(t:any,x:number,size=10,f=font)=>page.drawText(String(t??""),{x,y,size,font:f,color:rgb(0.12,0.12,0.12)});
  txt(inst?.nome||"NOVA TODDLE SCHOOL",45,18,bold); inline("DOCUMENTO FISCAL",420,12,bold); y-=2;
  txt(inst?.nif?"NIF: "+inst.nif:"",45,9); inline(String(tipo).toUpperCase()+" Nº "+(d.numero||""),420,10,bold); y-=2;
  txt("Data de emissão: "+(d.data_emissao||""),45,9); if(d.data_vencimento) txt("Vencimento: "+d.data_vencimento,45,9);
  y-=6; txt("CLIENTE",45,11,bold); txt(d.cliente_nome||"",45,10); txt("NIF: "+(d.cliente_nif||"Consumidor final"),45,9);
  if(d.cliente_email) txt("Email: "+d.cliente_email,45,9); if(d.cliente_telefone) txt("Telefone: "+d.cliente_telefone,45,9);
  y-=5; page.drawLine({start:{x:45,y},end:{x:550,y},thickness:1}); y-=18;
  inline("Descrição / Serviço",45,9,bold); inline("Qtd",360,9,bold); inline("Preço",410,9,bold); inline("Total",485,9,bold); y-=18;
  for(const l of (linhas||[])){ensure(); const yy=y; page.drawText(String(l.descricao||l.designacao||"Item"),{x:45,y:yy,size:9,font}); page.drawText(String(l.quantidade??1),{x:360,y:yy,size:9,font}); page.drawText(money(l.preco_unitario??l.valor_unitario),{x:410,y:yy,size:9,font}); page.drawText(money(l.total??l.valor),{x:485,y:yy,size:9,font}); y-=17;}
  y=Math.min(y,180); page.drawLine({start:{x:350,y},end:{x:550,y},thickness:1}); y-=18;
  inline("Subtotal:",350,9,bold); inline(money(d.subtotal)+" "+(d.moeda||"AOA"),455,9); y-=17;
  inline("Imposto:",350,9,bold); inline(money(d.imposto)+" "+(d.moeda||"AOA"),455,9); y-=19;
  inline("TOTAL:",350,12,bold); inline(money(d.total)+" "+(d.moeda||"AOA"),445,12,bold);
  y=85; inline("Estado: "+(d.estado||"emitido"),45,8); y-=14; inline("Hash fiscal: "+(d.hash_fiscal||"—"),45,7); y-=12;
  inline("Documento gerado pelo NOVA TODDLE SCHOOL",45,8);
  const bytes=await pdf.save(); const safe=String(d.numero||id).replace(/[^a-zA-Z0-9_-]/g,"_"); const path=String(d.instituicao_id)+"/"+safe+"_"+tipo+".pdf";
  const {error:up}=await sb.storage.from("documentos-fiscais").upload(path,bytes,{contentType:"application/pdf",upsert:true}); if(up) throw up;
  await sb.from("documentos_fiscais").update({storage_path:path}).eq("id",id);
  const {error:dg}=await sb.from("documentos_gerados").insert({instituicao_id:d.instituicao_id,documento_fiscal_id:id,tipo:tipo,formato:"pdf",conteudo_url:path,gerado_por:user.id,metadados:{numero:d.numero,estado:d.estado}}); if(dg) throw dg;
  const {data:signed,error:se}=await sb.storage.from("documentos-fiscais").createSignedUrl(path,3600); if(se) throw se;
  return new Response(JSON.stringify({ok:true,documento_fiscal_id:id,tipo,path,signed_url:signed?.signedUrl}),{headers:{...cors,"Content-Type":"application/json"}});
 }catch(e){return new Response(JSON.stringify({ok:false,error:String(e?.message||e)}),{status:400,headers:{...cors,"Content-Type":"application/json"}})}
});