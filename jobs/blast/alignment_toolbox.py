#***************************************************************
# The Alignment Toolbox
# This file contains functions that are useful in sequence analysis and manipulation of fasta files.
# All codes are written by Travis Johnson unless otherwise stated in function headers
# Dependencies include NetworkX, CUDAlign, optional: BioPython

# Update database (Still working...)
def updateDB():
	#awk '$9!~/processed_pseudogene/ && $9!~/unitary_pseudogene/' gencode.v25.primary_assembly_pseudogenes.annotation.gff3>gencode.v25.primary_assembly_other_pseudogenes.annotation.gff3
	#awk '$9!~/pseudogene/ && $9!~/retrotransposed/' gencode.v25.annotation.gff3>gencode.v25.genes.annotation.gff3
	return;

# fasta2Dict loads an external fasta file into a dictionary with keys as gene names
def fasta2Dict(fasta_file):
	sequences = dict();
	fin=open(fasta_file,'rb');
	line = fin.readline();
	while line != '':
		if line[0] == '>':
			if line.find(' ') != -1:
				name = line[1:line.find(' ')];
			else:
				name = line[1:len(line)-1];
			seq = '';
			line = fin.readline();
		while line != '':
			if line[0] == '>':
				break;
			else:
				seq = seq + line[0:len(line)-1];
				line = fin.readline();
		sequences[name] = seq;
	fin.close();
	return sequences

# hier2Dict loads a gene transcript hierarchy into a dictionary such that keys are gene names and values are lists of transcript names
def hier2Dict(gff3_file):
	hier = dict();
	fin=open(gff3_file,'rb');
	line = fin.readline();
	while line[0] == '#':						# Removes header
		line = fin.readline();
	line_vector = line.split('\t');
	while line != '':						# Reads through file until footer
		while line[0] == '#':
			line = fin.readline();
			if line == '':
				break;
		if line == '':
			break;
		line_vector = line.split('\t');
		if line_vector[2] == 'gene':
			key = line_vector[8][3:line_vector[8].find(';')];
			trans = [];
			line = fin.readline();
			line_vector = line.split('\t');
			while line_vector[2] != 'gene':		# Collects all transcripts associated with gene
				if line_vector[2] == 'transcript':
					trans.append(line_vector[8][3:line_vector[8].find(';')]);
					line=fin.readline();
					line_vector = line.split('\t');
				else:
					line=fin.readline();
					line_vector = line.split('\t');
				if line == '':
					break;
				elif line[0] == '#':
					break;
			hier[key] = trans;					# Adds gene and transcripts to dictionary
	#print line;
	return hier;

# mart2dict loads information into a dictionary from a mart export file
def mart2Dict(mart_file,delim):
	martDict = dict()
	fin = open(mart_file)
	line = fin.readline();
	line = line[:-1];
	line_vector = line.split(delim);
	past='';
	while line != '':
		if line_vector[0] == past:
			martDict[line_vector[0]] = martDict[line_vector[0]]+[line_vector[1:]];
		else:
			martDict[line_vector[0]] = [line_vector[1:]];
		past = line_vector[0];
		line = fin.readline();
		line = line[:-1];
		line_vector = line.split(delim);
	return martDict;

# gen_fasta create fasta file
def gen_fasta(gene_file,pseudogene_file,gene_names,fasta_output):
	genes = fasta2Dict(gene_file);
	psgenes = fasta2Dict(pseudogene_file);
	fout=open(fasta_output,'w');
	fin=open(gene_names,'rb');
	line = fin.readline();
	names = line.split(',');
	names = names[1:len(names)];
	for i in range(0,len(names)):
		if names[i][0] == '>':
			names[i] = names[i][1:len(names)];
		else:
			names[i] = names[i];
	names[len(names)-1] = names[len(names)-1][0:len(names[len(names)-2])];
	#print names
	for name in names:
		fout.write('>'+name+'\n');
		if name[0:4] == 'ENSG':
			fout.write(genes[name[0:name.find('.')]]+'\n');
		else:
			fout.write(psgenes[name[0:name.find('.')]]+'\n');

# Build an adjacency list from edge file (e.g. biomart homology) O(2n)
def build_adj_list(edge_file, delim, directed):
	# Importing gene names
	import csv;
	#import time;
	#beg = time.time();
	gnames_raw = [];
	gnames = [];
	adj_list = dict();
	fin=open(edge_file,'rb');
	i_1 = csv.reader(fin,delimiter=delim);
	f_list = list(i_1);
	for line in f_list:
		if line[0][0:4] == "ENSG":
			if line[1] == '':
				gnames_raw.append(line[0]);
			else:
				gnames_raw.append(line[0]);
				gnames_raw.append(line[1]);
	gnames = list(set(gnames_raw));
	for name in gnames:
		adj_list.update({name: []});
	fin.close()
	#print time.time()-beg
	# Importing edges into dictionary
	fin=open(edge_file,'rb');
	line = fin.readline();
	while line[0:4] != "ENSG":
		line = fin.readline();
	while line !='':
		line_vector = line.split(delim);
		if line_vector[1] != '\n':
			adj_list[line_vector[0]].append(line_vector[1][0:line_vector[1].find('\n')]);
			if not directed:
				adj_list[line_vector[0]] = list(set(adj_list[line_vector[0]]));
				adj_list[line_vector[1][0:line_vector[1].find('\n')]].append(line_vector[0]);
				adj_list[line_vector[1][0:line_vector[1].find('\n')]] = list(set(adj_list[line_vector[1][0:line_vector[1].find('\n')]]));
		line = fin.readline();
	#print time.time()-beg;
	return adj_list;

# Find connected components of graph (FASTER) (i.e. faster than nx package)
# Code from http://stackoverflow.com/questions/10301000/python-connected-components downloaded: 3/14/17
# Author: jimifiki
def getRoots(aNeigh):
    def findRoot(aNode,aRoot):
        while aNode != aRoot[aNode][0]:
            aNode = aRoot[aNode][0]
        return (aNode,aRoot[aNode][1])
    myRoot = {}
    for myNode in aNeigh.keys():
        myRoot[myNode] = (myNode,0)
    for myI in aNeigh:
        for myJ in aNeigh[myI]:
            (myRoot_myI,myDepthMyI) = findRoot(myI,myRoot)
            (myRoot_myJ,myDepthMyJ) = findRoot(myJ,myRoot)
            if myRoot_myI != myRoot_myJ:
                myMin = myRoot_myI
                myMax = myRoot_myJ
                if  myDepthMyI > myDepthMyJ:
                    myMin = myRoot_myJ
                    myMax = myRoot_myI
                myRoot[myMax] = (myMax,max(myRoot[myMin][1]+1,myRoot[myMax][1]))
                myRoot[myMin] = (myRoot[myMax][0],-1)
    myToRet = {}
    for myI in aNeigh:
        if myRoot[myI][0] == myI:
            myToRet[myI] = []
    for myI in aNeigh:
        myToRet[findRoot(myI,myRoot)[0]].append(myI)
    return myToRet

# keep only latest version number genes (i.e. ENSGXXXXXXXXXXX.4 over ENSGXXXXXXXXXXX.1) O(nlogn)
def get_latest(fasta_dict):
	old_dict = fasta_dict;
	new_dict = dict();
	for key in old_dict.keys():
		if key[key.find('.')+1:len(key)].isdigit():
			rep_keys = [k for k in old_dict.keys() if key[0:key.find('.')] in k];
			rep_keys_int = [k[key.find('.')+1:len(key)] for k in rep_keys if k[key.find('.')+1:len(key)].isdigit()];
			rep_keys_int = map(int,rep_keys_int);
			rep_keys_int.sort(reverse=True);
			new_dict[key[0:key.find('.')]] = fasta_dict[key[0:key.find('.')]+'.'+str(rep_keys_int[0])];
			for k in rep_keys:
				del old_dict[k];
	return new_dict;


# Returns the intersection of two lists
def intersection(a,b):
	return list(set(a) & set(b));
'''
# Loading and processing gfams to find consensus sequences
def get_cons_genes(edge_file, fasta_file, delim, directed, par_num, gfam_st, gfam_sp):
	import networkx as nx
	import numpy as np
	adjlist_graph = build_adj_list(edge_file, delim, directed);					# import adjacency list from edge file ~7min
	nx_graph = nx.from_dict_of_lists(adjlist_graph);							# convert adjacency list to an nx graph object
	gene_fasta = fasta2Dict(fasta_file);										# import gene sequences from fasta file
	#****************************************************************
	# Find bijection genes GENCODE to Ensembl
	# Remove genes from nx_graph which are not in the bijection
	gene_fasta = get_latest(gene_fasta);										# Retrieves the latest version of each gene ~7min
	keep_nodes = intersection(gene_fasta.keys(),nx_graph.nodes());				# Finds intersection of nx graph nodes and fasta genes (latest version)
	rem_nodes = [node for node in nx_graph.nodes() if node not in keep_nodes];	# Creates lists of nodes to remove from nx graph
	for node in rem_nodes:														# Removes gene-nodes from nx graph
		nx_graph.remove_node(node);
	#****************************************************************
	subgraphs = list(nx.connected_component_subgraphs(nx_graph));				# Finds subgraphs from nx graph
	# Getting top <=2 consensus genes using BC and Alignscores
	BCout=open('cons_genes'+str(gfam_st)+'-'+str(gfam_sp)+'_BC.txt','w');
	ALout=open('cons_genes'+str(gfam_st)+'-'+str(gfam_sp)+'_AL.txt','w');
	i = gfam_st;
	while i < gfam_sp+1:
	# Outputting gene families with few genes (i.e. no processing required)
		print len(nx.to_dict_of_lists(subgraphs[i-1]))
		if len(nx.to_dict_of_lists(subgraphs[i-1])) < 3:
			tmp = nx.to_dict_of_lists(subgraphs[i-1]);
			BCout.write(str(i)+',');
			ALout.write(str(i)+',');
			if len(tmp.keys()) == 1:
				print tmp.keys()[0]							#testing
				BCout.write(str(tmp.keys()[0])+'\n');
				ALout.write(str(tmp.keys()[0])+'\n');
			elif len(tmp.keys()) == 0:
				print 'Error empty gene family subgraph';
			else:
				print tmp.keys()[0]+','+tmp.keys()[1]		#testing
				BCout.write(str(tmp.keys()[0])+','+str(tmp.keys()[1])+'\n');
				ALout.write(str(tmp.keys()[0])+','+str(tmp.keys()[1])+'\n');
		# Outputting gene families with many genes (i.e. processing required)
		else:
			# Outputting BC consensus genes
			BCout.write(str(i));
			BC = nx.betweenness_centrality(subgraphs[i-1])
			for node in BC.keys():
				if BC[node] > 0:
					print node								#testing
					BCout.write(','+node);
			BCout.write('\n');
			# Outputting AL consensus genes
			tmp_seq_dict = {key:gene_fasta[key] for key in subgraphs[i-1]};
			tmp_align_mat = alignMatrix_cuda(tmp_seq_dict,par_num);
			alignMatrix2file(tmp_align_mat,tmp_seq_dict.keys(),'gfam_alignMats/alignMat_'+str(i)+'.txt');
			ind = np.argsort(np.mean(tmp_align_mat,axis=1));
			print str(i)+','+tmp_seq_dict.keys()[ind[len(ind)-1]]+','+tmp_seq_dict.keys()[ind[len(ind)-2]] 				#testing
			ALout.write(str(i)+','+str(tmp_seq_dict.keys()[ind[len(ind)-1]])+','+str(tmp_seq_dict.keys()[ind[len(ind)-2]])+'\n');
		i=i+1;
'''

def base_names(data_dict):
	for key in data_dict.keys():
		data_dict[key[0:key.index('.')]] = data_dict.pop(key);
	return data_dict;

# Calculating highest alignment scores between pseudogenes and gfams
def pseudogene_gfam_alignment(cons_gene_file, gene_full_file, gene_transcript_file, psgene_file, hier_file, type, par_num, pg_st, pg_sp, offset):
	import csv
	import os
	import time
	import numpy as np
	beg = time.time();
	# Add code here
	fin = open(cons_gene_file,'rU');
	i_1 = csv.reader(fin, delimiter=",")
	cons_gene_list = list(i_1);
	fin.close();
	del i_1;
	gene_full_dict = get_latest(fasta2Dict(gene_full_file));
	gene_transcript_dict = fasta2Dict(gene_transcript_file);
	psgene_dict = fasta2Dict(psgene_file);
	gene_hier_dict = get_latest(hier2Dict(hier_file));
	print 'finished importing files: '+str(time.time()-beg)
	os.system('mkdir tmp'+str(par_num));
	# os.system('cp ~/recomb-2017/masa-cudalign/cudalign $TMPDIR');		# ************Testing**************
	fout = open('tmp'+str(par_num)+'/seq'+str(1)+'.fa','w')
	#fout = open('seq1.fa','w')
	fout.write('>'+psgene_dict.keys()[pg_st]+'\n')
	fout.write(psgene_dict[psgene_dict.keys()[pg_st]]+'\n')
	fout.close();
	status_file = open('status_'+str(pg_st)+'.txt','w');
	scores = np.zeros((len(cons_gene_list),1));
	if type == 'processed':
		#align to associated transcripts and return best align for each gene
		i = 0;
		while i < len(cons_gene_list):
			j = 1;
			gene_scores = np.zeros((len(cons_gene_list[i])-1,1));
			while j < len(cons_gene_list[i]):
				k = 0;
				trans_scores = np.zeros((len(gene_hier_dict[cons_gene_list[i][j]]),1));
				while k < len(gene_hier_dict[cons_gene_list[i][j]]):
					fout = open('tmp'+str(par_num)+'/seq'+str(2)+'.fa','w')
					#fout = open('seq2.fa','w')
					fout.write('>'+gene_hier_dict[cons_gene_list[i][j]][k]+'\n')
					fout.write(gene_transcript_dict[gene_hier_dict[cons_gene_list[i][j]][k]]+'\n')
					fout.close()
					trans_scores[k] = cudalign((1,2),par_num);
					k = k + 1;
				gene_scores[j-1] = max(trans_scores);
				j = j + 1;
			scores[i] = max(gene_scores);
			if i%100 == 0:
				status_file.write(str(i)+': '+str(time.time()-beg)+'\n');
				status_file.close();
				os.system('rm $HOME/status_files/status_'+str(pg_st)+'.txt');
				os.system('cp status_'+str(pg_st)+'.txt $HOME/status_files');
				status_file = open('status_'+str(pg_st)+'.txt','a');
			i = i + 1;
	elif type == 'unprocessed':
		i = 0;
		while i < len(cons_gene_list):
			j = 1;
			gene_scores = np.zeros((len(cons_gene_list[i])-1,1));
			while j < len(cons_gene_list[i]):
				fout = open('tmp'+str(par_num)+'/seq'+str(2)+'.fa','w')
				#fout = open('seq2.fa','w')
				fout.write('>'+cons_gene_list[i][j]+'\n')
				fout.write(gene_full_dict[cons_gene_list[i][j]]+'\n')
				fout.close();
				gene_scores[j-1] = cudalign((1,2),par_num);
				j = j + 1;
			scores[i] = max(gene_scores);
			i = i + 1;
	elif type =='other':
		i = 0;
		while i < len(cons_gene_list):
			j = 1;
			gene_scores = np.zeros((len(cons_gene_list[i])-1,1));
			while j < len(cons_gene_list[i]):
				k = 0;
				trans_scores = np.zeros((len(gene_hier_dict[cons_gene_list[i][j]]),1));
				while k < len(gene_hier_dict[cons_gene_list[i][j]]):
					fout = open('tmp'+str(par_num)+'/seq'+str(2)+'.fa','w')
					#fout = open('seq2.fa','w')
					fout.write('>'+gene_hier_dict[cons_gene_list[i][j]][k]+'\n')
					fout.write(gene_transcript_dict[gene_hier_dict[cons_gene_list[i][j]][k]]+'\n')
					fout.close()
					trans_scores[k] = cudalign((1,2),par_num);
					k = k + 1;
				gene_scores[j-1] = max(trans_scores);
				j = j + 1;
			tmp1 = max(gene_scores);
			j = 1;
			gene_scores = np.zeros((len(cons_gene_list[i])-1,1));
			while j < len(cons_gene_list[i]):
				fout = open('tmp'+str(par_num)+'/seq'+str(2)+'.fa','w')
				#fout = open('seq2.fa','w')
				fout.write('>'+cons_gene_list[i][j]+'\n')
				fout.write(gene_full_dict[cons_gene_list[i][j]]+'\n')			# Fixing*********
				fout.close();
				gene_scores[j-1] = cudalign((1,2),par_num);
				j = j + 1;
			tmp2 = max(gene_scores);
			scores[i] = max(tmp1,tmp2)
			i = i + 1;
	else:
		print 'Unknown type: enter processed, unprocessed, or other'
		return
	status_file.write(str(time.time() - beg));
	status_file.close();
	np.savetxt('scores'+str(pg_st+offset)+'.csv',scores,delimiter=",");
	os.system('mv scores'+str(pg_st+offset)+'.csv $PBS_O_WORKDIR/pseudo_scores');

# alignMatrix_pw  uses the Biopython pairwise alignment algorithm to align each possible pair of sequences
# within a dictionary of sequences. This code is easily parrallelizable but is slow
def alignMatrix_pw(sequence_dict):
	if len(sequence_dict.keys())**2 > 1800:
		print 'Warning: Serial runtime estimated: %0.2f hours' % (((len(sequence_dict.keys())**2)/360)*2)
	from Bio import pairwise2
	import numpy as np
	dim = len(sequence_dict);
	aMatrix = np.empty([dim,dim])
	for i in range(0,dim):
		for j in range(0,i):
			aMatrix[i,j] = pairwise2.align.localxx(sequence_dict[sequence_dict.keys()[i]],sequence_dict[sequence_dict.keys()[j]],score_only=True);
			aMatrix[j,i] = aMatrix[i,j];
	return aMatrix

# cudalign calls the cudalign algorithm from the shell and extracts the alignment score from the output (FAST)
def cudalign(seqs, par_num):
		seq_num1 = seqs[0]
		seq_num2 = seqs[1]
		import os
		while not os.path.exists('tmp'+str(par_num)+'/work.tmp'+str(seq_num1)+'-'+str(seq_num2)+'/statistics_01.00'):		#New untested
			os.system('./cudalign --stage-1 --verbose=0 --work-dir=tmp'+str(par_num)+'/work.tmp'+str(seq_num1)+'-'+str(seq_num2)+' tmp'+str(par_num)+'/seq'+str(seq_num1)+'.fa tmp'+str(par_num)+'/seq'+str(seq_num2)+'.fa')
		fin = open('tmp'+str(par_num)+'/work.tmp'+str(seq_num1)+'-'+str(seq_num2)+'/statistics_01.00')
		line = fin.readline()
		while line[3:14]!='Best Score:' and line != '':
			line = fin.readline()
		else:
			fin.close()
		os.system('rm -rf tmp'+str(par_num)+'/work.tmp'+str(seq_num1)+'-'+str(seq_num2))
		return int(line[15:len(line)-1])

# alignMatrix_cuda calls the cudalign function to produce a matrix of the alignment scores for every
# combination of pairwise alignments for a dictionary of sequences, fast but not easily parrallelizable
def alignMatrix_cuda(sequence_dict, par_num):
	# Loading libraries
	import numpy as np
	import os
	#Defining input params
	dim = len(sequence_dict)
	aMatrix = np.zeros([dim,dim])
	os.system('mkdir tmp'+str(par_num))
	for i in range(0,dim):
		fout = open('tmp'+str(par_num)+'/seq'+str(i)+'.fa','w')
		fout.write('>'+sequence_dict.keys()[i]+'\n')
		fout.write(sequence_dict[sequence_dict.keys()[i]]+'\n')
	fout.close()
	tup = []
	for i in range(0,dim):
		for j in range(0,i):
			tup.append([i,j])
			aMatrix[i,j] = cudalign((i,j),par_num)
			aMatrix[j,i] = aMatrix[i,j]
	os.system('rm -rf tmp'+str(par_num))
	return aMatrix

# alignMatrix2file outputs the alignment matrix to an external csv file with the indice names (gene names or dict keys)
def alignMatrix2file(A,indices,file):
	fout = open(file,'w');
	fout.write(',');
	indlen = len(indices);
	for i in range(0,indlen):
		if i < indlen-1:
			fout.write(indices[i]+',');
		else:
			fout.write(indices[i]+'\n');
	for i in range(0,indlen):
		fout.write(indices[i]+',')
		for j in range(0,indlen):
			if j < indlen-1:
				fout.write(str(A[i,j])+',');
			else:
				fout.write(str(A[i,j])+'\n');

# alignMatrixMulti loads fasta files computes thier alignment matrix and outputs the alignment csv such that
# multiple fasta files can be run in sequence
def alignMatrixMulti(start,stop,infile_prefix,outfile_prefix,par_num):
	import os
	for i in range(start,stop):
		if os.path.isfile(infile_prefix+str(i)+'.txt'):
			if os.stat(infile_prefix+str(i)+'.txt').st_size > 0:
				f = fasta2Dict(infile_prefix+str(i)+'.txt')
				A = alignMatrix_cuda(f,par_num)
				alignMatrix2file(A,f.keys(),outfile_prefix+str(i)+'.csv')

# loadAlignMatrix loads alignment matrix files into a numpy array
def loadAlignMatrix(file):
	import numpy as np;
	fin = open(file,'rb');
	line = fin.readline();
	line = line[1:len(line)-1];
	names = line.split(',');
	dim = len(names);
	aMatrix = np.empty([dim,dim]);
	for i in range(0,dim):
		line = fin.readline();
		line = line[line.find(',')+1:len(line)-1];
		row = line.split(',');
		aMatrix[i,:] = [float(j) for j in row];
	return aMatrix

# addGOfeats2adjmat loads an adjacency matrix from file then adds GO terms and gene symbols exports networkx graph
def addGOfeats2adjmat(adjmat,gnames,gene_symbol_file,GO_term_file,tree):
	import numpy as np
	import networkx as nx
	go_terms = mart2Dict(GO_term_file,',');
	gene_sym = mart2Dict(gene_symbol_file,',');
	#adjmat = loadAlignMatrix(adjmat_file);
	#fin = open(adjmat_file,'rb');
	#gnames = fin.readline();
	#fin.close();
	#gnames = gnames[1:-1];
	#gnames = gnames.split(',');
	G = nx.from_numpy_matrix(adjmat*-1);
	for i in range(len(G)):
		#G.node[i]['gencodeID'] = gnames[i];
		if gnames[i][:gnames[i].find('.')] in gene_sym.keys():
			if len(gene_sym[gnames[i][:gnames[i].find('.')]]) > 0:
				G.node[i]['gene_symbol'] = gene_sym[gnames[i][:gnames[i].find('.')]][0][0];
		else:
			G.node[i]['gene_symbol'] = '';
		if gnames[i][:gnames[i].find('.')] in go_terms.keys():
			if len(go_terms[gnames[i][:gnames[i].find('.')]]) > 0:
				for term in go_terms[gnames[i][:gnames[i].find('.')]]:
					if 'GOaccessions' in G.node[i]:
						'''
						G.node[i]['GOaccessions'] = G.node[i]['GOaccessions']+[term[0]];
						G.node[i]['GOnames'] = G.node[i]['GOnames']+[term[1]];
						G.node[i]['GOdescriptions'] = G.node[i]['GOdescriptions']+[term[2]];
						'''
						G.node[i]['GOaccessions'] = G.node[i]['GOaccessions']+'|'+term[0];
						G.node[i]['GOnames'] = G.node[i]['GOnames']+'|'+term[1];
						G.node[i]['GOdescriptions'] = G.node[i]['GOdescriptions']+'|'+term[2];
					else:
						G.node[i]['GOaccessions'] = term[0];
						G.node[i]['GOnames'] = term[1];
						G.node[i]['GOdescriptions'] = term[2];
		else:
			G.node[i]['GOaccessions'] = '';
			G.node[i]['GOnames'] = '';
			G.node[i]['GOdescriptions'] = '';
	if tree == True:
		i = 0;
		conv_dict = dict();
		for name in gnames:
			conv_dict[i] = name[:name.find('.')];
			i = i+1;
		H = nx.relabel_nodes(G,conv_dict);
		T = nx.minimum_spanning_tree(H);
		for u,v,d in T.edges(data=True):
			d['weight']*=-1;
		return T;
	else:
		return G;

# Blast searches !!!!!!
def blastsearch(sequence, name):
	import os
	fout = open('input.fa','w');
	fout.write('>'+name+'\n');
	fout.write(sequence+'\n');
	fout.close()
	os.system('blastn -query input.fa -db merged_formatted.fa -out blastsearch_results.txt -word_size 7');
	fin = open('blastsearch_results.txt','rb');
	line = fin.readline();
	while '***** No hits found *****' not in line and 'Sequences producing significant alignments:' not in line:
		line = fin.readline();
	os.system('rm blastsearch_results.txt');
	if '***** No hits found *****' in line:
		print 'No hits found in the database';
		return -1;
	elif 'Sequences producing significant alignments:' in line:
		line = fin.readline();
		line = fin.readline();
		line = line[2:len(line)];
		return line[0:line.find(' ')];
	else:
		print 'Error in blastsearch: could not read result of negative from result file';

def generate_tree(search_sequence, search_name, addGOterms):
	import numpy as np
	import networkx as nx
	from networkx.readwrite import json_graph
	import json
	#search gene_families for the gene returned by blastsearch
	closest_gene = blastsearch(search_sequence, search_name);
	# Find gene family with gene
	for num in range(1,46754):
		try:
			fin = open('/users/PAS1294/osu8658/website/pgAmats/pgAmat'+str(num)+'.csv','rb');
			line = fin.readline()
			names = line.split(',');
			fin.close()
			if closest_gene in names:
				break
		except:
			x=1;
	gdict = fasta2Dict('/users/PAS1294/osu8658/website/pg_fams/pggfam'+str(num)+'.fa');
	gdict[search_name] = search_sequence;
	alignmat = alignMatrix_cuda(gdict, 1);
	print alignmat;
	if addGOterms:
		T = addGOfeats2adjmat(alignmat,gdict.keys(),'gene_symbols.txt','GO_terms.txt',True);
	else:
		#generate maximum spanning tree
		alignmat = alignmat*-1;
		G = nx.from_numpy_matrix(alignmat);
		print G.nodes()
		conv_dict = dict();
		i = 0;
		for name in gdict.keys():
			conv_dict[i] = name;
			i = i+1;
		H = nx.relabel_nodes(G,conv_dict);
		T = nx.minimum_spanning_tree(H);
		for u,v,d in T.edges(data=True):
			d['weight']*=-1;
	outdat = json_graph.node_link_data(T);
	fout = open('outgraph.json','w');
	json.dump(outdat,fout);
	fout.close();

# unnormLaplac calculates the unnormalized laplacian as described by Ng 2002
def unnormLaplac(A):
	import numpy as np
	D = np.zeros([A.shape[0],A.shape[0]])
	for i in range(0,A.shape[0]):
		D[i,i] = sum(A[i,:]);
		A[i,i] = 0;
	L = D - A;
	return L;

# normLaplac calculates the normalized laplacian as described by Ng 2002
def normLaplac(A):
	import numpy as np
	D = np.zeros(A.shape)
	iD = np.zeros(A.shape)
	for i in range(0,A.shape[0]):
		D[i,i] = sum(A[i,:]);
		iD[i,i] = sum(A[i,:])**(-1/2);
		A[i,i] = 0;
	L = D - A;
	Lnorm = iD*L*iD;
	return Lnorm

# specClust runs spectral clustering on a laplacian
def specClust(L,comps,k):
	import numpy as np
	import scipy.cluster as sc
	eigvals, eigvecs = np.linalg.eig(L)
	x,y = sc.vq.kmeans2(eigvecs[:,0:comps-1],k)
	return y;


#************************************************************
# For testing
def test(x):
	import multiprocessing as mp
	pool = mp.Pool(processes=12)
	results = pool.map(run,range(1,40))
	return results

def run(y):
		import os
		os.system('./masa-cudalign/cudalign --help')
		#os.system('echo hi')
		return y



