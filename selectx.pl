selectx(X,[X|Xs],Xs).
selectx(X,[Y|Ys],[Y|Zs]) :- selectx(X,Ys,Zs).

selecty(X,Y,Z) :- selectx(X,Y,Z),X=\=1.
