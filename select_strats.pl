:-dynamic(protocol/2).

%% first consult the E strategy protocols (the cnf-versions should have
%% different names), then run
%% get_best_protocols(15,Protocols,CoveredNr,UncoveredNr,TotalNr,A),write([Protocols,CoveredNr,UncoveredNr,TotalNr,A]).
%% to get the 15 protocols with widest coverage, and see there statistics.
%% Note: this is done greedily, the result set can be suboptimal.


zip([],[],[]).
zip([H|T],[H1|T1],[[H,H1]|T2]):- zip(T,T1,T2).

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
%% this now also reports the time needed for solving the added problems
get_added_value2(PLs,PL2,N,AddedTime,AddedProblems):-
	findall([Problem,Time],
 		(member([Problem,Time],PL2), not(member(Problem,PLs))),
 		AddedPairs),
	length(AddedPairs,N),
	zip(AddedProblems,Times,AddedPairs),
	sumlist(Times,AddedTime).



% get_added_value([PL1|PLs],PL2,N):-
% 	findall(Problem,
% 		(member([Problem,_],PL2), not(member([Problem,_],PL1))),
% 		AddedProblems1),
% 	get_added_value(PLs,AddedProblems1,N).

get_allprot_names(AllNames):- findall(Prot,protocol(Prot,_),AllNames1), sort(AllNames1,AllNames).

get_solved(Prots,Solved):- findall(Prob,(member(Prot,Prots),protocol(Prot,PList),member([Prob|_],PList)),Solved1), sort(Solved1,Solved).

union_l([],SortedIn,SortedIn).
union_l([H|T],SortedIn,Result):-
	union(H,SortedIn,Tmp1),
	union_l(T,Tmp1,Result).	

get_best_protocols(Size,Protocols,CoveredNr,UncoveredNr,TotalNr,AddedNrList):-
	get_allprot_names(AllNames),
	get_solved(AllNames,AllSolved),
	length(AllSolved,TotalNr),
	get_best_prots(Size,[],AllNames,Protocols,0,CoveredNr,[],AddedNrList),
	UncoveredNr is TotalNr - CoveredNr.
	

get_best_prots(0,ProtsSoFar,_,ProtsSoFar,CoveredSoFar,CoveredSoFar,AddedNrsSoFar,AddedNrsSoFar):- !.

get_best_prots(N,ProtsSoFar,ProtsToDo,Result,CoveredSoFar,ResultCovered,AddedNrsSoFar,AddedNrList):-
	maplist(protocol,ProtsSoFar,ProtListsSoFar),
	maplist(flatten,ProtListsSoFar,ProtListsSoFar1),
	maplist(sublist(atom),ProtListsSoFar1,ProtListsSoFar2),
	union_l(ProtListsSoFar2,[],ProtListsSoFar3),!,
	findall([AddedNr,NegTime,Prot,AddedProbs],
		(
		  member(Prot,ProtsToDo),
		  protocol(Prot,ProbList),
		  get_added_value2(ProtListsSoFar3,ProbList,AddedNr,AddedTime,AddedProbs),
		  NegTime is 0 - AddedTime   %% negate, so the smallest is last after sorting
		),
		Res1),
	sort(Res1,Res2),
	last(Res2,[BestAdded,BestNegTime,BestProt,BestAddedProbs]),
	delete(ProtsToDo,BestProt,ProtsToDo1),
	N1 is N - 1,
	CoveredSoFar1 is CoveredSoFar + BestAdded,
	protocol(BestProt,BestProtList),
	length(BestProtList,BestSolved),
	BestTime is 0 - BestNegTime, !,
	get_best_prots(N1,[BestProt|ProtsSoFar],ProtsToDo1,Result,CoveredSoFar1,ResultCovered,
		       [BestAdded:BestTime:BestSolved:BestAddedProbs|AddedNrsSoFar],AddedNrList).
	


	       
