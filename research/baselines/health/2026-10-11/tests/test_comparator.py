from __future__ import annotations
import copy
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from compare_health_probes import compare

resolved={'exists':True,'enumerationStatus':'ok',
          'methods':[{'name':'setHpValue','signature':'setHpValue(System.Single, System.Boolean)',
                      'signatureStatus':'resolved','returnType':'System.Void','isStatic':False}],
          'overloadsByName':{'setHpValue':1},
          'fields':{'Hit':{'exists':True,'type':'app.Hit'}}}
base={'probeVersion':'1.0','tdbVersion':'83','reframeworkInfo':{'gameName':'dd2','commitHash':'abc'},
      'engine':{'sdk':{'find_type_definition':True}},
      'types':{'app.Hit':copy.deepcopy(resolved)},
      'runtime':{'playerReadPath':'get_ManualPlayer()',
                 'hitControllerTypeResolved':'app.Hit','pawnListAvailable':True,
                 'player':{'hitAvailable':True,'hitAccessPath':'character.<Hit>k__BackingField',
                           'hitRuntimeType':'app.Hit','hp':100,'reducedMaxHp':100,'originalMaxHp':100}}}

new=copy.deepcopy(base)
new['runtime']['player']['hp']=50
new['runtime']['player']['reducedMaxHp']=90
new['runtime']['pawnListCount']=9
assert not compare(base,new)[0], 'Dynamic health values must not be compared.'

new=copy.deepcopy(base)
new['types']['app.Hit']['methods'][0]['signature']='setHpValue(System.Single)'
assert any('removed/changed' in d for d in compare(base,new)[0])

new=copy.deepcopy(base)
new['types']['app.Hit']['fields']['Hit']['type']='app.NewHit'
assert any('.field.Hit.type' in d for d in compare(base,new)[0])

new=copy.deepcopy(base)
new['runtime']['player']['hitAccessPath']='get_Hit'
assert any('hitAccessPath' in d for d in compare(base,new)[0])

new=copy.deepcopy(base)
new['types']['app.Hit']['enumerationStatus']='error'
assert any('incomplete' in w for w in compare(base,new)[1])
print('Comparator tests passed: HP changes ignored, signatures/fields/access-paths detected')
