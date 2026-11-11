import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {Workbook, SpreadsheetFile} from '@oai/artifact-tool';
const dir = '/Users/alexanderilivanov/Projects/pyramida/outputs/resource-menu-balance-2026-11-10';
const config = JSON.parse(await fs.readFile('/Users/alexanderilivanov/Projects/pyramida/data/settlement/reviewed_balance.json','utf8'));
const wb = Workbook.create();
const current = wb.worksheets.add('Current balance');
const review = wb.worksheets.add('Review gaps');
const resources = ['log','grain','plank','stone','block','clay','imbrex','rope'];
const benefits = {
  house:'3 resident places',support:'Stacking',stair:'Floor access',road:'35% faster walking',
  sawmill:'Log → Plank',log_shed:'8 shared Log / Plank spaces',hay_barn:'8 shared Hay / Flour spaces',
  stone_storage:'18 shared Stone / Slab spaces',brickyard:'18 shared Clay / Brick spaces',
  well:'1–3 Water capacity at 2 m depth',hay_field:'Harvest Hay',mill:'Hay → Flour',bakery:'Flour → Food',
  quarry:'Gather Stone; 4 buffer spaces',masonry:'Stone → Slab',claypit:'Gather Clay; requires Puddle',
  pottery_workshop:'Clay → Vase',kiln:'Clay → Brick',mine:'Gather Ore',tilery:'Clay → Imbrex'
};
const items = config.buildings.map(b=>({name:b.name,cost:b.cost,benefit:benefits[b.id],status:b.id==='sawmill'?'Source mismatch':b.cost_status==='provisional_balance'?'Provisional':b.cost_status==='confirmed_free'?'Confirmed free':'Reviewed'}));
items.push({name:'Rope maker',cost:config.additional_construction.rope_maker,benefit:'Hay → Rope',status:'Missing in source'});
for(const tier of [2,3]) items.push({name:`House upgrade ${tier}`,cost:config.house_tiers.upgrade_costs[tier],benefit:tier===2?'Board roof; stacking enabled':'Imbrex roof',status:'Provisional'});
current.getRange('A2').values = [['Current construction balance']];
current.getRange('A3').values = [['10 November 2026. Item counts; blank material cells mean zero. Existing gameplay prices retained.']];
current.getRange('A5:K5').values = [['Building','Log','Hay','Plank','Stone','Slab','Clay','Imbrex','Rope','Provides','Price status']];
const rows=items.map(b=>[b.name,...resources.map(r=>b.cost[r]??0),b.benefit,b.status]);
current.getRange(`A6:K${5+rows.length}`).values=rows;
current.getRange(`B6:I${5+rows.length}`).setNumberFormat('0;[Red](0);""');
current.getRange('A31').values=[['Rope bridge']];
current.getRange('A32:C35').values=[['Curved deck length (m)',5,null],['Material','Rate / m','Cost'],['Plank',config.rope_bridge_cost.planks_per_metre,null],['Rope',config.rope_bridge_cost.rope_per_metre,null]];
current.getRange('C34:C35').formulas=[['=ROUNDUP($B$32*B34,0)'],['=ROUNDUP($B$32*B35,0)']];
current.getRange('B32').setNumberFormat('0.0');
current.getRange('B34:B35').setNumberFormat('0.0');
current.getRange('C34:C35').setNumberFormat('0');
current.getRange('E32').values=[['Each material rounds up; measure the curved deck, not endpoint distance.']];
current.getRange('A38').values=[['Game configuration: data/settlement/reviewed_balance.json (restart to reload).']];
current.getRange('A39').values=[['Timings: game_settings.cfg. Resident places: scripts/settlement/house_groups.gd.']];
current.getRange('A40').values=[['This workbook is a review copy. Edits here do not update the game.']];
review.getRange('A2').values=[['Source differences and missing entries']];
review.getRange('A4:D4').values=[['Item','Attached Numbers file','Current game','Source location']];
const differences=[
 ['Sawmill','4 Hay + 4 Log','4 Log; keep price until resolved','Tier 1!G6:H6'],
 ['Claypit','Price blank; named Claypot','2 Log, provisional','Tier 1!A17:M17'],
 ['Mine','Price blank','4 Log, provisional','Tier 1!A20:M20'],
 ['Quarry','Price blank','Free, previously confirmed','Tier 1!A15:M15'],
 ['Tilery','Missing','4 Stone + 4 Clay; Clay → Imbrex','Not in source'],
 ['Rope maker','Missing','4 Log; Hay → Rope','Not in source'],
 ['Rope bridge','Missing','1 Plank/m + 0.5 Rope/m, rounded up','Not in source'],
 ['House upgrade 2','Missing','2 Log + 4 Plank, provisional','Not in source'],
 ['House upgrade 3','Missing','2 Plank + 4 Imbrex, provisional','Not in source'],
 ['Resident places','Not specified','3 per completed reachable House','Tier 1!A2:F2'],
 ['Mill size','3 × 3 × 2 m','3 × 3 × 5 m; later approved size','Tier 1!B13'],
 ['Deepest Well','8 m','6 m; water capacities still 9 / 6','Water and storage!B9, B17'],
 ['Storage meaning','Paired resources and Store value','One shared capacity, not per material','Tier 1!C7:F10'],
 ['Building availability','Tier 1 roster','Current menu also contains rope tools','data/settlement/catalog.gd'],
];
review.getRange(`A5:D${4+differences.length}`).values=differences;
review.getRange('A21').values=[['Sources']];
review.getRange('A22').values=[['Attached: /Users/alexanderilivanov/Downloads/Pyramida_Game_Balance_Reviewed.numbers']];
review.getRange('A23').values=[['Runtime: data/settlement/reviewed_balance.json; data/settlement/catalog.gd; game_settings.cfg']];
review.getRange('A24').values=[['Housing: scripts/settlement/house_groups.gd. Bridge: scripts/settlement/rope_bridges.gd.']];
review.getRange('A26').values=[['Missing sheet values are not treated as zero prices. No balance decisions were inferred from document text.']];
for(const sheet of [current,review]){
 sheet.showGridLines=false;
 const range=sheet.getUsedRange();
 range.format.font={name:'Arial',size:11,color:'#352719'};
 range.format.rowHeight=26;
 range.format.verticalAlignment='center';
 sheet.getRange('A2').format.font={name:'Arial',size:16,bold:true,color:'#352719'};
 sheet.freezePanes.freezeRows(sheet===current?5:4);
}
current.getRange('A1:A40').format.columnWidth=24;
current.getRange('B1:I40').format.columnWidth=9;
current.getRange('J1:J40').format.columnWidth=44;
current.getRange('K1:K40').format.columnWidth=22;
review.getRange('A1:A26').format.columnWidth=24;
review.getRange('B1:B26').format.columnWidth=36;
review.getRange('C1:C26').format.columnWidth=49;
review.getRange('D1:D26').format.columnWidth=37;
for(const [sheet,range] of [[current,'A5:K5'],[current,'A33:C33'],[review,'A4:D4']]){
 sheet.getRange(range).format.fill='#64452f';
 sheet.getRange(range).format.font={name:'Arial',size:11,bold:true,color:'#FFFFFF'};
}
current.getRange('B32').format.fill='#FFF0C8';
for(let r=6;r<=5+rows.length;r+=2) current.getRange(`A${r}:K${r}`).format.fill='#F7F1E6';
for(let r=5;r<=4+differences.length;r+=2) review.getRange(`A${r}:D${r}`).format.fill='#F7F1E6';
wb.recalculate();
assert.deepEqual(current.getRange('C34:C35').values,[[5],[3]]);
current.getRange('B32').values=[[2.1]];
wb.recalculate();
assert.deepEqual(current.getRange('C34:C35').values,[[3],[2]]);
current.getRange('B32').values=[[5]];
wb.recalculate();
assert.deepEqual(current.getRange(`B6:I${5+rows.length}`).values,rows.map(r=>r.slice(1,9)));
console.log((await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#NUM!',options:{useRegex:true,maxResults:10},maxChars:1500})).ndjson);
for(const [sheet,range,name] of [['Current balance','A1:K29','current'],['Current balance','A31:K40','bridge'],['Review gaps','A1:D26','review']]){
 const png=await wb.render({sheetName:sheet,range,scale:1,format:'png'});
 await fs.writeFile(`${dir}/${name}.png`,new Uint8Array(await png.arrayBuffer()));
}
await (await SpreadsheetFile.exportXlsx(wb)).save(`${dir}/Pyramida_Current_Balance.xlsx`);
console.log('Exported current balance and source review; bridge recalculation verified.');
