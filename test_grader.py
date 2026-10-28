"""Fictional fixtures only. Run: python -m unittest -v test_grader"""
import copy
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
from zipfile import ZipFile
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, HTTPServer
import grader as g


class GraderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'SmithA01234567.docx'
        original = g.RES / 'Official Template.docx'
        with ZipFile(original) as z:
            root = ET.fromstring(z.read('word/document.xml'))
            pars = root.find('w:body', g.NS).findall('w:p', g.NS)
            for i,p in enumerate(pars):
                text = ''.join(t.text or '' for t in p.findall('.//w:t',g.NS))
                if text in ('Business Need for Project','Background'):
                    ts = pars[i+1].findall('.//w:t',g.NS)
                    ts[0].text = ('Integration gaps threaten fixed-price margins.' if text.startswith('Business')
                                  else 'Greenify supplies sensors and analytics to cities.')
                    for t in ts[1:]: t.text = ''
            with ZipFile(self.path,'w') as out:
                for info in z.infolist():
                    out.writestr(info,ET.tostring(root) if info.filename=='word/document.xml' else z.read(info))
        self.result={'criteria':[{'criterion':c,'score':2,'feedback':'Explain the business implications.',
                                'evidence':'Integration gaps threaten fixed-price margins.'}
                               for c in g.CRITERIA[:5]],
                     'final_feedback':'The business issue is clear. Explain its consequences more fully.'}

    def test_official_structure_and_section_boundaries(self):
        x=g.inspect_document(self.path)
        self.assertEqual(x['missing_headings'],[])
        self.assertEqual(x['missing_table_labels'],[])
        self.assertTrue(x['heading_order_ok'])
        self.assertTrue(x['filename_ok'])
        self.assertEqual(x['sections']['Business Need for Project'],'Integration gaps threaten fixed-price margins.')
        self.assertNotIn('Status Reporting',x['sections']['Background'])

    def test_end_to_end_mocked_model(self):
        calls=[]
        def local(endpoint,payload=None,**kwargs):
            calls.append((endpoint,payload))
            if endpoint=='/api/tags': return {'models':[{'name':g.MODEL}]}
            return {'message':{'content':json.dumps(self.result)},'done_reason':'stop'}
        with patch.object(g,'local_request',side_effect=local):
            result=g.grade(self.path)
        self.assertEqual(len(result['criteria']),7)
        self.assertEqual([r['score'] for r in result['criteria'][-2:]],[3,3])
        sent=json.loads(calls[1][1]['messages'][1]['content'])
        self.assertEqual(set(sent['student_sections_to_assess']),{'Background','Business Need for Project'})
        self.assertNotIn('purple elephants',sent['instructor_reference_data'])

    def test_unsubstantiated_quote_and_invalid_grade_rejected(self):
        x=g.inspect_document(self.path)
        bad=copy.deepcopy(self.result); bad['criteria'][0]['evidence']='Fabricated evidence'
        with self.assertRaises(ValueError):g.validate_result(bad,x['sections'])
        bad=copy.deepcopy(self.result); bad['criteria'][0]['score']=0
        with self.assertRaises(ValueError):g.validate_result(bad,x['sections'])

    def test_feedback_required_and_full_mark_comments_omitted(self):
        x=g.inspect_document(self.path)
        bad=copy.deepcopy(self.result);bad['criteria'][0]['feedback']=''
        with self.assertRaises(ValueError):g.validate_result(bad,x['sections'])
        good=copy.deepcopy(self.result);good['criteria'][0]['score']=3
        g.validate_result(good,x['sections'])
        self.assertEqual(good['criteria'][0]['feedback'],'')

    def test_export_penalty_is_separate(self):
        rows=self.result['criteria']+[
            {'criterion':g.CRITERIA[5],'score':3,'feedback':''},
            {'criterion':g.CRITERIA[6],'score':3,'feedback':''}]
        plain=g.feedback_text(self.path.name,rows,'Clear start. Add detail.',False)
        penalized=g.feedback_text(self.path.name,rows,'Clear start. Add detail.',True)
        self.assertIn('Rubric total: 16/21',plain)
        self.assertNotIn('50%',plain)
        self.assertIn('Final mark: 8/21',penalized)

    def test_empty_template_is_not_presented_as_substantive_text(self):
        x=g.inspect_document(g.RES/'Official Template.docx')
        self.assertIn('empty',x['sections']['Background'])

    def test_http_loopback_and_redirect_refusal(self):
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path=='/redirect':
                    self.send_response(302);self.send_header('Location','https://example.com');self.end_headers()
                else:
                    self.send_response(200);self.end_headers();self.wfile.write(b'{"models":[]}')
            def log_message(self,*args):pass
        server=HTTPServer(('127.0.0.1',0),Handler)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            with patch.object(g,'API','http://127.0.0.1:'+str(server.server_port)):
                self.assertEqual(g.local_request('/api/tags'),{'models':[]})
                with self.assertRaises(ValueError):g.local_request('/redirect')
        finally:
            server.shutdown();server.server_close();thread.join()

if __name__=='__main__':unittest.main()
