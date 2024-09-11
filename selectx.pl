selectx(X,[X|Xs],Xs).
selectx(X,[Y|Ys],[Y|Zs]) :- selectx(X,Ys,Zs).
