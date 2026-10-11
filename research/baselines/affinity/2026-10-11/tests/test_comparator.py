import json
import sys
import unittest
from pathlib import Path
from copy import deepcopy
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from compare_probes_v12 import compare

class CompareTests(unittest.TestCase):
 def setUp(self):
  self.old={'probeVersion':'1.2','tdbVersion':'83','types':{'app.NPCHolder':{'exists':True,'enumerationStatus':'ok','enumeratedMethodCount':5,'methods':[{'name':'addSentimentValue','signatureStatus':'resolved','signature':'addSentimentValue(System.Int32)','returnType':'System.Void','isStatic':False}],'overloadsByName':{'addSentimentValue':1},'fields':{}}},'reframeworkInfo':{'commitHash':'abcdef','gameName':'dd2'},'engine':{},'runtime':{'playerAvailable':True}}
 def test_same(self):
  a,b=compare(self.old,deepcopy(self.old))
  self.assertEqual(a,[])
 def test_signature_changed(self):
  other=deepcopy(self.old);other['types']['app.NPCHolder']['methods'][0]['signature']='addSentimentValue(System.Single)'
  a,b=compare(self.old,other)
  self.assertTrue(any('signatures' in x for x in a))
 def test_unresolved_not_false_claim(self):
  other=deepcopy(self.old);other['types']['app.NPCHolder']['methods'][0]['signatureStatus']='unresolved'
  a,b=compare(self.old,other)
  self.assertFalse(any('signatures' in x for x in a))
  self.assertTrue(any('incomplete parameter' in x for x in b))
 def test_old_probe_does_not_spuriously_report_signature_changed(self):
  other=deepcopy(self.old);other['probeVersion']='1.1';other['types']['app.NPCHolder']['methods'][0]['signatureStatus']=None
  a,b=compare(other,self.old)
  self.assertFalse(any('signatures' in x for x in a))
  self.assertTrue(any('Probe version' in x for x in b))
 def test_missing_name(self):
  other=deepcopy(self.old);other['types']['app.NPCHolder']['methods']=[]
  a,b=compare(self.old,other)
  self.assertTrue(any('names disappeared' in x for x in a))
 def test_runtime_difference_is_warning(self):
  other=deepcopy(self.old);other['runtime']['playerAvailable']=False
  a,b=compare(self.old,other)
  self.assertEqual(a,[])
  self.assertTrue(any('scene-dependent' in x for x in b))
if __name__=='__main__': unittest.main()
