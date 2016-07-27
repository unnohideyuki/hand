package jp.ne.sakura.uhideyuki.brt.runtime;

import jp.ne.sakura.uhideyuki.brt.brtsyn.*;

import java.util.Arrays;

class ConsFunc implements LambdaForm {
    public int arity(){ return 2; }
    public Expr call(AtomExpr[] args){
	assert args.length == 2;
	return new AtomExpr(new Var(new ConObj(new Cotr("Prim.:"), args)));
    }
}

class PutStrLnFunc implements LambdaForm {
    public int arity(){ return 1; }
    public Expr call(AtomExpr[] args){
	assert args.length == arity();
	String t = RTLib.toJString(RT.eval(args[0]));
	System.out.println(t);
	return RTLib.app(Prim.mkretIO(), RTLib.unit);
    }
}

public class RTLib {
    private static Expr mkExpr(HeapObj obj){
	return new AtomExpr(new Var(obj));
    }

    private static Expr mkExpr(char c){
	return new AtomExpr(new LitChar(c));
    }

    public static Expr mkFun(LambdaForm lam){
	return mkExpr(new FunObj(lam.arity(), lam));
    }

    public static Expr cons = mkFun(new ConsFunc());

    public static String toJString(Expr s){
	StringBuilder t = new StringBuilder();

	while(true){
	    if (s.isConObj()){
		ConObj con = (ConObj)((Var)((AtomExpr)s).a).obj;
		if (con.cotr.ident == "Prim.:"){
		    Expr c = RT.eval(con.args[0]);
		    t.append(((LitChar)((AtomExpr)c).a).value);
		    s = RT.eval(con.args[1]);
		} else {
		    break;
		}
	    }
	}
	return t.toString();
    }

    public static Expr unit =
	mkExpr(new ConObj(new Cotr("Prim.()"), new AtomExpr[0]));

    public static Expr nil =
	mkExpr(new ConObj(new Cotr("Prim.[]"), new AtomExpr[0]));

    public static Expr app(Expr f, Expr a1, Expr a2){
	assert a1 instanceof AtomExpr;
	assert a2 instanceof AtomExpr;
	AtomExpr[] args = {(AtomExpr) a1, (AtomExpr) a2};
	return mkExpr(new Thunk(new FunAppExpr(f, args, -1)));
    }
	       
    public static Expr app(Expr f, Expr a){
	assert a instanceof AtomExpr;
	AtomExpr[] args = {(AtomExpr) a};
	return mkExpr(new Thunk(new FunAppExpr(f, args, -1)));
    }
	       
    private static Expr fromJCharArray(char[] s){
	if (s.length == 0){
	    return nil;
	} else if (s.length == 1){
	    // return app(cons, mkExpr(s[0]), nil);
	    AtomExpr[] args = {(AtomExpr) mkExpr(s[0]), (AtomExpr) nil};
	    return new AtomExpr(new Var(new ConObj(new Cotr("Prim.:"), args)));
	}
	
	char[] t = Arrays.copyOfRange(s, 1, s.length);
	// return app(cons, mkExpr(s[0]), fromJCharArray(t));
	AtomExpr[] args = {(AtomExpr) mkExpr(s[0]), 
			   (AtomExpr) fromJCharArray(t)};
	return new AtomExpr(new Var(new ConObj(new Cotr("Prim.:"), args)));
    }
	       
    public static Expr fromJString(String s){
	return fromJCharArray(s.toCharArray());
    }

    public static Expr putStrLn = mkFun(new PutStrLnFunc());

    public static Expr fromChar(char c){ return mkExpr(c); }

    public static Expr fromInteger(Integer i){
	return new AtomExpr(new LitInt(i));
    }

    public static Object extrDict(AtomExpr e){
	Dict d = (Dict) e.a;
	return d.obj;
    }
}
