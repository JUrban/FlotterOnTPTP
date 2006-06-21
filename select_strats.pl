:-dynamic(protocol/2).

%% first consult the E strategy protocols (the cnf-versions should have
%% different names), then run
%% get_best_protocols(15,Protocols,CoveredNr,UncoveredNr,TotalNr,A),write([Protocols,CoveredNr,UncoveredNr,TotalNr,A]).
%% to get the 15 protocols with widest coverage, and see there statistics.
%% Note: this is done greedily, the result set can be suboptimal.

%% get_added_value(+ProtocolsSoFar,+CurrentProtocol,-ProblemsAddedNr,-AddedProblems)
get_added_value0(ProtocolNamesSoFar,CurrentProtocolName,ProblemsAddedNr,AddedProblems):-
	maplist(protocol,[CurrentProtocolName|ProtocolNamesSoFar],[CurrentProtocolList|ProtocolListsSoFar]),
	get_added_value(ProtocolListsSoFar,CurrentProtocolList,ProblemsAddedNr,AddedProblems).

get_added_value(PLs,PL2,N,AddedProblems):-
	flatten(PLs,PLs1),
	sort(PLs1,PLs2),
	findall(Problem,
 		(member([Problem,_],PL2), not(member(Problem,PLs2))),
 		AddedProblems),
	length(AddedProblems,N).

%% when PLs is flattened and sorted already and PL2 is list of problems
get_added_value2(PLs,PL2,N,AddedProblems):-
	findall(Problem,
 		(member([Problem,_],PL2), not(member(Problem,PLs))),
 		AddedProblems),
	length(AddedProblems,N).


% get_added_value([PL1|PLs],PL2,N):-
% 	findall(Problem,
% 		(member([Problem,_],PL2), not(member([Problem,_],PL1))),
% 		AddedProblems1),
% 	get_added_value(PLs,AddedProblems1,N).

get_allprot_names(AllNames):- findall(Prot,protocol(Prot,_),AllNames1), sort(AllNames1,AllNames).

get_solved(Prots,Solved):- findall(Prob,(member(Prot,Prots),protocol(Prot,PList),member([Prob|_],PList)),Solved1), sort(Solved1,Solved).


get_best_protocols(Size,Protocols,CoveredNr,UncoveredNr,TotalNr,AddedNrList):-
	get_allprot_names(AllNames),
	get_solved(AllNames,AllSolved),
	length(AllSolved,TotalNr),
	get_best_prots(Size,[],AllNames,Protocols,0,CoveredNr,[],AddedNrList),
	UncoveredNr is TotalNr - CoveredNr.
	

get_best_prots(0,ProtsSoFar,_,ProtsSoFar,CoveredSoFar,CoveredSoFar,AddedNrsSoFar,AddedNrsSoFar):- !.

get_best_prots(N,ProtsSoFar,ProtsToDo,Result,CoveredSoFar,ResultCovered,AddedNrsSoFar,AddedNrList):-
	maplist(protocol,ProtsSoFar,ProtListsSoFar),
	flatten(ProtListsSoFar,ProtListsSoFar1),
	sublist(atom,ProtListsSoFar1,ProtListsSoFar2),
	sort(ProtListsSoFar2,ProtListsSoFar3),
	findall([AddedNr,Prot,AddedProbs],
		(
		  member(Prot,ProtsToDo),
		  protocol(Prot,ProbList),
		  get_added_value2(ProtListsSoFar3,ProbList,AddedNr,AddedProbs)
		),
		Res1),
	sort(Res1,Res2),
	last(Res2,[BestAdded,BestProt,BestAddedProbs]),
	delete(ProtsToDo,BestProt,ProtsToDo1),
	N1 is N - 1,
	CoveredSoFar1 is CoveredSoFar + BestAdded,
	protocol(BestProt,BestProtList),
	length(BestProtList,BestSolved), !,
	get_best_prots(N1,[BestProt|ProtsSoFar],ProtsToDo1,Result,CoveredSoFar1,ResultCovered,
		       [BestAdded:BestSolved:BestAddedProbs|AddedNrsSoFar],AddedNrList).
	


	       
