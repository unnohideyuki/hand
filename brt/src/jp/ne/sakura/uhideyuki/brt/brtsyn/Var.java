package jp.ne.sakura.uhideyuki.brt.brtsyn;

public class Var extends Atom {
    public HeapObj obj;
    public Var(HeapObj x){ obj = x; }

    public String inspect(){
	return "Var(obj=" + obj.inspect() + ")";
    }
}
