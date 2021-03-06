from __future__ import absolute_import
from django.shortcuts import render
from django.shortcuts import redirect
from django.http import Http404
from django.http import HttpResponse
from django.conf import settings
from django.core.cache import cache
from uuid import uuid4
from os import path, makedirs, chmod, remove
from blast.models import BlastQueryRecord, BlastDb
from blast.tasks import run_blast_task
from datetime import datetime, timedelta
from django.utils.timezone import localtime, now
from pytz import timezone
import json
import traceback
import stat as Perm
from itertools import groupby
from multiprocessing import cpu_count
from util.get_bin_name import get_bin_name
import pdb

blast_customized_options = {'blastn': ['max_target_seqs', 'evalue', 'word_size', 'reward', 'penalty', 'gapopen', 'gapextend', 'strand', 'low_complexity', 'soft_masking'],
                            'tblastn': ['max_target_seqs', 'evalue', 'word_size', 'matrix', 'threshold', 'gapopen', 'gapextend', 'low_complexity', 'soft_masking'],
                            'tblastx': ['max_target_seqs', 'evalue', 'word_size', 'matrix', 'threshold', 'strand', 'low_complexity', 'soft_masking'],
                            'blastp': ['max_target_seqs', 'evalue', 'word_size', 'matrix', 'threshold', 'gapopen', 'gapextend', 'low_complexity', 'soft_masking'],
                            'blastx': ['max_target_seqs', 'evalue', 'word_size', 'matrix', 'threshold', 'strand', 'gapopen', 'gapextend', 'low_complexity', 'soft_masking']}
# blast_col_name = 'qseqid sseqid evalue qlen slen length nident mismatch positive gapopen gaps qstart qend sstart send bitscore qcovs qframe sframe'
blast_col_name = 'qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore nident qcovs qlen slen qframe sframe'
blast_col_names_display = 'Query sequence ID,Subject sequence ID,Percentage of identical matches,Alignment length,Number of mismatches,Number of gap openings,Start of alignment in query,End of alignment in query,Start of alignment in subject,End of alignment in subject,Expect value,Bit score,Number of identical matches,Query coverage per subject,Query sequence length,Subject sequence length,Query frame,Subject frame'.split(',')
blast_info = {
    'col_types': ['str', 'str', 'float', 'int', 'int', 'int', 'int', 'int', 'int', 'int', 'float', 'float', 'int', 'int', 'int', 'int', 'int', 'int'],
    'col_names': blast_col_name.split(),
    'ext': {
        '.0': '0',
        '.html': '0',
        '.1': '1',
        '.3': '3',
        '.xml': '5',
        '.tsv': '6 ' + blast_col_name,
    },
}

def manual(request):
    '''
        Manual page of tutorial
    '''
    return render(request,'blast/manual.html',{'title':'Blast Manual'})

def create(request, iframe=False):
    if request.method == 'GET':
        blastdb_list = sorted([[db.type.dataset_type, db.type.get_molecule_type_display(), db.title, db.organism.display_name, db.description] for db in BlastDb.objects.select_related('organism').select_related('type').filter(is_shown=True) if db.db_ready()], key=lambda x: (x[3], x[1], x[0], x[2]))
        blastdb_type_counts = dict([(k.lower().replace(' ', '_'), len(list(g))) for k, g in groupby(sorted(blastdb_list, key=lambda x: x[0]), key=lambda x: x[0])])
        return render(request, 'blast/main.html', {
            'title': 'BLAST Query',
            'blastdb_list': json.dumps(blastdb_list),
            'blastdb_type_counts': blastdb_type_counts,
            'iframe': iframe
        })
    elif request.method == 'OPTIONS':
        return HttpResponse("OPTIONS METHOD NOT SUPPORTED", status=202)
    elif request.method == 'POST':
        # setup file paths
        task_id = uuid4().hex  # TODO: Create from hash of input to check for duplicate inputs
        file_prefix = path.join(settings.MEDIA_ROOT, 'blast', 'task', task_id, task_id)
        query_filename = file_prefix + '.in'
        asn_filename = file_prefix + '.asn'
        if not path.exists(path.dirname(query_filename)):
            makedirs(path.dirname(query_filename))
        chmod(path.dirname(query_filename), Perm.S_IRWXU | Perm.S_IRWXG | Perm.S_IRWXO) # ensure the standalone dequeuing process can open files in the directory
        bin_name = get_bin_name()
        # write query to file
        if 'query-file' in request.FILES:
            with open(query_filename, 'wt') as query_f:
                for chunk in request.FILES['query-file'].chunks():
                    query_f.write(chunk)
        elif 'query-sequence' in request.POST:
            with open(query_filename, 'wt') as query_f:
                query_text = [x.encode('utf-8', 'ignore').strip().decode('utf-8')
                              for x in request.POST['query-sequence'].split('\n')]
                query_f.write('\n'.join(query_text))
        else:
            return render(request, 'blast/invalid_query.html', {'title': 'Invalid Query'})

        

        if (path.getsize(query_filename) > int(settings.BLAST_QUERY_SIZE_MAX) * 1024):
            return render(request, 'blast/invalid_query.html', {'title': 'Your query size is ' + str(path.getsize(query_filename)) + ' bytes, but exceeds our query size limit of ' + str(settings.BLAST_QUERY_SIZE_MAX) + ' kbytes,  Please try again with a smaller query size.',})

        chmod(query_filename, Perm.S_IRWXU | Perm.S_IRWXG | Perm.S_IRWXO) # ensure the standalone dequeuing process can access the file

        # build blast command
        db_list = ' '.join([db.fasta_file.path_full for db in BlastDb.objects.filter(title__in=set(request.POST.getlist('db-name'))) if db.db_ready()])
        if not db_list:
            return render(request, 'blast/invalid_query.html', {'title': 'Invalid Query',})

        # check if program is in list for security
        if request.POST['program'] in ['blastn', 'tblastn', 'tblastx', 'blastp', 'blastx']:

            with open(query_filename, 'r') as f:
                qstr = f.read()
                if(qstr.count('>') > int(settings.BLAST_QUERY_MAX)):
                    query_cnt = str(qstr.count('>'))
                    remove(query_filename)
                    return render(request, 'blast/invalid_query.html',
                            {'title': 'Your search includes ' + query_cnt + ' sequences, but blast allows a maximum of ' + str(settings.BLAST_QUERY_MAX) + ' sequences per submission.', })

            # generate customized_options
            input_opt = []
            max_target_seqs = request.POST.get('max_target_seqs', 50)
            for blast_option in blast_customized_options[request.POST['program']]:
                if blast_option == 'low_complexity':
                    if request.POST['program'] == 'blastn':
                        input_opt.extend(['-dust', request.POST['low_complexity']])
                    else:
                        input_opt.extend(['-seg', request.POST['low_complexity']])
                else:
                    input_opt.extend(['-'+blast_option, request.POST[blast_option]])

            program_path = path.join(settings.BASE_DIR, 'blast', bin_name, request.POST['program'])
            num_threads = '4' if cpu_count() >= 4 else str(cpu_count())
            args_list = [[program_path, '-query', query_filename, '-db', db_list, '-outfmt', '11', '-out', asn_filename, '-num_threads', num_threads]]
            args_list[0].extend(input_opt)

            # convert to multiple formats
            blast_formatter_path = path.join(settings.BASE_DIR, 'blast', bin_name, 'blast_formatter')
            for ext, outfmt in blast_info['ext'].items():
                args = [blast_formatter_path, '-archive', asn_filename, '-outfmt', outfmt, '-out', file_prefix + ext]
                if ext == '.html':
                    args.append('-html')
                if int(outfmt.split()[0]) > 4:
                    args.extend(['-max_target_seqs', max_target_seqs])
                else:
                    args.extend(['-num_descriptions', max_target_seqs, '-num_alignments', max_target_seqs])
                args_list.append(args)
            record = BlastQueryRecord()
            record.task_id = task_id
            if request.user.is_authenticated:
                record.user = request.user
            record.save()

            # generate status.json for frontend status checking
            with open(query_filename, 'rt') as f:
                # count number of query sequence by counting '>'
                qstr = f.read()
                seq_count = qstr.count('>')
                if (seq_count == 0):
                    seq_count = 1
                with open(path.join(path.dirname(file_prefix), 'status.json'), 'wt') as f:
                    json.dump({'status': 'pending', 'seq_count': seq_count}, f)

            
            run_blast_task.delay(task_id, args_list, file_prefix, blast_info)

            # debug
            # run_blast_task.delay(task_id, args_list, file_prefix, blast_info).get()
            return redirect('blast:retrieve', task_id)
        else:
            raise Http404


def retrieve(request, task_id='1'):
    try:
        r = BlastQueryRecord.objects.get(task_id=task_id)
        
        # if result is generated and not expired
        if r.result_date and (r.result_date.replace(tzinfo=None) >= (datetime.utcnow()+ timedelta(days=-7))):
            if r.result_status in ['SUCCESS', 'NO_GFF']:
                file_prefix = path.join(settings.MEDIA_ROOT, 'blast', 'task', task_id, task_id)
                results_info = ''
                with open(path.join(settings.MEDIA_ROOT, 'blast', 'task', task_id, 'info.json'), 'rt') as f:
                    results_info = f.read()
                results_data = ''

                with open(file_prefix + '.json', 'rt') as f:
                    results_data = f.read()
                results_detail = ''
                with open(file_prefix + '.0', 'rt') as f:
                    results_detail = f.read()
                results_col_names = blast_info['col_names']
                results_col_names_display = blast_col_names_display
                results_col_names = ['blastdb'] + results_col_names
                results_col_names_display = ['BLAST Database Title'] + results_col_names_display
                return render(
                    request,
                    'blast/results.html', {
                        'title': 'BLAST Result',
                        'results_col_names': json.dumps(results_col_names),
                        'results_col_names_display': json.dumps(results_col_names_display),
                        'results_detail': json.dumps(results_detail),
                        'results_data': results_data,
                        'results_info': results_info,
                        'task_id': task_id,
                    })
            else:  # if .tsv file size is 0, no hits found
                return render(request, 'blast/results_not_existed.html', {
                    'title': 'No Hits Found',
                    'isNoHits': True,
                    'isExpired': False,
                })
        else:
            enqueue_date = r.enqueue_date.astimezone(timezone('US/Eastern')).strftime('%d %b %Y %X %Z')
            if r.dequeue_date:
                dequeue_date = r.dequeue_date.astimezone(timezone('US/Eastern')).strftime('%d %b %Y %X %Z')
            else:
                dequeue_date = None
            # result is exipired
            isExpired = False
            if r.result_date and (r.result_date.replace(tzinfo=None) < (datetime.utcnow()+ timedelta(days=-7))):
                isExpired = True
            return render(request, 'blast/results_not_existed.html', {
                'title': 'Query Submitted',
                'task_id': task_id,
                'isExpired': isExpired,
                'enqueue_date': enqueue_date,
                'dequeue_date': dequeue_date,
                'isNoHits': False,
            })
    except Exception:
        raise Http404


def read_gff3(request, task_id, dbname):
    output = '##gff-version 3\n'
    try:
        if request.method == 'GET':
            with open(path.join(settings.MEDIA_ROOT, 'blast', 'task', task_id, dbname) + '.gff', 'rt') as f:
                output = f.read()
    finally:
        return HttpResponse(output)


def status(request, task_id):
    if request.method == 'GET':
        status_file_path = path.join(settings.MEDIA_ROOT, 'blast', 'task', task_id, 'status.json')
        status = {'status': 'unknown'}
        if path.isfile(status_file_path):
            with open(status_file_path, 'rt') as f:
                statusdata = json.load(f)
                if statusdata['status'] == 'pending' and settings.USE_CACHE:
                    tlist = cache.get('task_list_cache', [])
                    num_preceding = -1
                    if tlist:
                        for index, t in enumerate(tlist):
                            if task_id in t:
                                num_preceding = index
                                break
                    statusdata['num_preceding'] = num_preceding
                elif statusdata['status'] == 'running':
                    asn_path = path.join(settings.MEDIA_ROOT, 'blast', 'task', task_id, (task_id+'.asn'))
                    if path.isfile(asn_path):
                        with open(asn_path, 'rt') as asn_f:
                            astr = asn_f.read()
                            processed_seq_count = astr.count('title \"')
                            statusdata['processed'] = processed_seq_count
                    else:
                        statusdata['processed'] = 0
                return HttpResponse(json.dumps(statusdata))
        return HttpResponse(json.dumps(status))
    else:
        return HttpResponse('Invalid Post')


# to-do: integrate with existing router of restframework
from rest_framework.renderers import JSONRenderer
from .serializers import UserBlastQueryRecordSerializer
class JSONResponse(HttpResponse):
    """
    An HttpResponse that renders its content into JSON.
    """
    def __init__(self, data, **kwargs):
        content = JSONRenderer().render(data)
        kwargs['content_type'] = 'application/json'
        super(JSONResponse, self).__init__(content, **kwargs)

def user_tasks(request, user_id):
    """
    Return tasks performed by the user.
    """
    if request.method == 'GET':
        records = BlastQueryRecord.objects.filter(user__id=user_id, is_shown=True, result_date__gt=(localtime(now())+ timedelta(days=-7)))
        serializer = UserBlastQueryRecordSerializer(records, many=True)
        return JSONResponse(serializer.data)

