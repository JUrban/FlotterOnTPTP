:-dynamic(protocol/2).
:-dynamic(all_solved/1).
:-dynamic(prot_problems/2).
:-dynamic(solved_so_far/1).
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
get_added_value2(PLs,Prot,N,AddedTime,AddedProblems):-
	protocol(Prot,PL2),
	prot_problems(Prot,PL2Problems),
	subtract(PL2Problems,PLs,AddedProblems),
	findall(Time,
		(member(Problem,AddedProblems), once(member([Problem,Time],PL2))),
 		Times),
	length(AddedProblems,N),
	sumlist(Times,AddedTime).

not_solved_so_far(X):- not(solved_so_far(X)).

get_added_value3(_PLs,Prot,N,AddedTime,AddedProblems):-
	protocol(Prot,PL2),
	prot_problems(Prot,PL2Problems),
	sublist(not_solved_so_far,PL2Problems,AddedProblems),
	findall(Time,
		(member(Problem,AddedProblems), once(member([Problem,Time],PL2))),
 		Times),
	length(AddedProblems,N),
	sumlist(Times,AddedTime).



% get_added_value([PL1|PLs],PL2,N):-
% 	findall(Problem,
% 		(member([Problem,_],PL2), not(member([Problem,_],PL1))),
% 		AddedProblems1),
% 	get_added_value(PLs,AddedProblems1,N).

get_allprot_names(AllNames):- findall(Prot,protocol(Prot,_),AllNames1), sort(AllNames1,AllNames).


assert_solved(Prots):-
	findall(Prot,(member(Prot,Prots),protocol(Prot,PList),
		      findall(Prob,member([Prob|_],PList),Solved1),
		      assert(prot_problems(Prot,Solved1))),
		_).

get_solved(Prots,Solved):- findall(Prob,(member(Prot,Prots),protocol(Prot,PList),member([Prob|_],PList)),Solved1), sort(Solved1,Solved).

union_l([],SortedIn,SortedIn).
union_l([H|T],SortedIn,Result):-
	union(H,SortedIn,Tmp1),
	union_l(T,Tmp1,Result).	

get_best_protocols(Size,Protocols,CoveredNr,UncoveredNr,TotalNr,AddedNrList):-
	get_allprot_names(AllNames),
	assert_solved(AllNames),
	retractall(solved_so_far(_)),
	get_solved(AllNames,AllSolved),
	assert(all_solved(AllSolved)),
	length(AllSolved,TotalNr),
	get_best_prots(Size,[],AllNames,Protocols,0,CoveredNr,[],AddedNrList),
	UncoveredNr is TotalNr - CoveredNr.
	

get_best_prots(0,ProtsSoFar,_,ProtsSoFar,CoveredSoFar,CoveredSoFar,AddedNrsSoFar,AddedNrsSoFar):- !.

get_best_prots(N,ProtsSoFar,ProtsToDo,Result,CoveredSoFar,ResultCovered,AddedNrsSoFar,AddedNrList):-
%	maplist(protocol,ProtsSoFar,ProtListsSoFar),
%	maplist(flatten,ProtListsSoFar,ProtListsSoFar1),
	% atom selects just the problem names, not the times
%	maplist(sublist(atom),ProtListsSoFar1,ProtListsSoFar2),
%	union_l(ProtListsSoFar2,[],ProtListsSoFar3),!,
	findall([AddedNr,NegTime,Prot,AddedProbs],
		(
		  member(Prot,ProtsToDo),
		  once(get_added_value3(_,Prot,AddedNr,AddedTime,AddedProbs)),
		  NegTime is 0 - AddedTime   %% negate, so the smallest is last after sorting
		),
		Res1),
	sort(Res1,Res2),
	last(Res2,[BestAdded,BestNegTime,BestProt,BestAddedProbs]),
	findall(p,(member(Pr1,BestAddedProbs),assert(solved_so_far(Pr1))),_),
	delete(ProtsToDo,BestProt,ProtsToDo1),
	N1 is N - 1,
	CoveredSoFar1 is CoveredSoFar + BestAdded,
	protocol(BestProt,BestProtList),
	length(BestProtList,BestSolved),
	BestTime is 0 - BestNegTime, !,
	get_best_prots(N1,[BestProt|ProtsSoFar],ProtsToDo1,Result,CoveredSoFar1,ResultCovered,
		       [BestAdded:BestTime:BestSolved:BestAddedProbs|AddedNrsSoFar],AddedNrList).
	


	       
