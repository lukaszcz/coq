(***********************************************************************
        Utilitaires.
*)

(* Impression *)

let pr x =
  if !Flags.debug then (Format.printf "@[%s@]" x; flush(stdout);)else ()

let prn x =
  if !Flags.debug then (Format.printf "@[%s\n@]" x; flush(stdout);) else ()

let prt0 s = () (* print_string s;flush(stdout)*)

let prt s =
  if !Flags.debug then (print_string (s^"\n");flush(stdout)) else ()

let info s =
  output_string stderr s; flush stderr

(**********************************************************************
      Tableaux 
*)
(* compte les occurrences de i dans le tableau t *)
let compte t i =  
   let r = ref 0 in 
   Array.iter (fun x -> if x=i then r:= !r + 1) t;
   !r ;;

(* maximum d'un tableau d'entiers *)
let maximum t = 
   Array.fold_left max 0 t
;;


(* appliquer une fonction a tous les elements d'une matrice *)
let matrix_map f m=
  let s=Array.length m in
  let res=Array.create s [| |] in
    for i=0 to s-1 do
      res.(i)<-Array.map f m.(i)
    done;
res
;;
(* selectionne dans un tableau *)
let array_select f l =
  let res = ref [] in
  Array.iter (fun x -> if (f x) then res:=(!res)@[x]) l;
  Array.of_list !res
;;
(* teste si tous les elements d'un tableau verifient f *)
let array_test f t =
   try (Array.iter (fun x -> if not (f x) then failwith "raté") t;
        true)
   with _ -> false
;;

(* cherche a dans t, rend l'indice ou il se trouve ou declenche une exception*)
let array_find a t =
  let n = Array.length t in
  let ok = ref true in
  let res = ref 0 in
    while !ok do
      if (!res = n) then raise Not_found
else (if t.(!res) = a then ok := false
      else res := !res +1;)
    done;
!res
;;

(**********************************************************************
  Listes
*)

let set_of_list l =
  let r = Hashtbl.create 51 in
    List.iter (fun x ->
		 try (Hashtbl.find r x;())
		 with _ -> Hashtbl.add r x true) l;
    let res = ref [] in
      Hashtbl.iter (fun x _ -> res:=x::(!res)) r;
      !res
	
(* appartenance à une liste , on donne l'égalité *)
let rec list_mem_eq eq x l =
  match l with
    [] -> false
   |y::l1 -> if (eq x y) then true else (list_mem_eq eq x l1)
;;

(* vire les repetitions d'une liste, on donne l'égalité *)
let set_of_list_eq eq l =
   let res = ref [] in
   List.iter (fun x -> if not (list_mem_eq eq x (!res)) then res:=x::(!res)) l;
   List.rev !res 
;;

(* selectionne dans une liste *)
let list_select f l =
  let res = ref [] in
  List.iter (fun x -> if (f x) then res:=(!res)@[x]) l;
  !res
;;

(***********************************************************************
 Un outil pour faire une mémo-fonction:
 fonction est la fonction(!)
 memoire est une référence au graphe déjà calculé 
    (liste de couples, c'est une variable globale)
 egal est l'égalité sur les arguments
 valeur est une valeur possible de la fonction (sert uniquement pour le typage)
*)

let memo memoire egal valeur fonction x =
   let res = ref valeur in
   try (List.iter (fun (y,v) -> if egal y x
		       then (res:=v;
			     failwith "trouve"))
	          !memoire;
        let v = fonction x in
	memoire:=(x,v)::(!memoire);
	v)
   with _ -> !res
;;

(* un autre plus efficace, 
   utilisant une fonction intermediaire (utile si on n'a pas
   l'égalité = sur les arguments de fonction) 
   s chaîne imprimée s'il n'y a pas calcul *)

let memos s memoire print fonction x =
   try (let v = Hashtbl.find memoire (print x) in pr s;v)
   with _ -> (pr "#";
	      let v = fonction x in
	      Hashtbl.add memoire (print x) v;
	      v)
;;

(**********************************************************************
  Eléments minimaux pour un ordre partiel de division.
  E est un ensemble, avec une multiplication 
  et une division partielle div (la fonction div peut échouer), 
  constant est un prédicat qui définit un sous-ensemble C de E.
*)
(*
  Etant donnée une partie A de E, on calcule une partie B de E disjointe de C
  telle que:
    - les éléments de A sont des produits d'éléments de B et d'un de C.
    - B est minimale pour cette propriété.
*)

let facteurs_liste div constant lp =
   let lp = list_select (fun x -> not (constant x)) lp in
   let rec factor lmin lp = (* lmin: ne se divisent pas entre eux *)
      match lp with
        [] -> lmin
       |p::lp1 ->
         (let l1 = ref [] in
          let p_dans_lmin = ref false in
          List.iter (fun q -> try (let r = div p q in
                                   if not (constant r)
				   then l1:=r::(!l1)
                                   else p_dans_lmin:=true)
			      with _ -> ())
                     lmin;
          if !p_dans_lmin
          then factor lmin lp1
          else if (!l1)=[]
          (* aucun q de lmin ne divise p *)
          then (let l1=ref lp1 in
		let lmin1=ref [] in
                List.iter (fun q -> try (let r = div q p in
					 if not (constant r)
					 then l1:=r::(!l1))
				    with _ -> lmin1:=q::(!lmin1))
                          lmin;
	        factor (List.rev (p::(!lmin1))) !l1)
          (* au moins un q de lmin divise p non trivialement *)
          else factor lmin ((!l1)@lp1))
    in
    factor [] lp
;;

(* On suppose que tout élément de A est produit d'éléments de B et d'un de C:
   A et B sont deux tableaux,  rend un tableau de couples
      (élément de C, listes d'indices l)
   tels que A.(i) = l.(i)_1*Produit(B.(j), j dans l.(i)_2)
   zero est un prédicat sur E tel que (zero x) => (constant x):
         si (zero x) est vrai on ne decompose pas x
   c est un élément quelconque de E.
*)
let factorise_tableau div zero c f l1 =
    let res = Array.create (Array.length f) (c,[]) in
    Array.iteri (fun i p ->
      let r = ref p in
      let li = ref [] in
      if not (zero p)
      then 
      Array.iteri (fun j q ->
	              try (while true do
                               let rr = div !r q in
      	                       li:=j::(!li);
                               r:=rr;
			   done)
                      with _ -> ())
                  l1;
      res.(i)<-(!r,!li))
     f;
    (l1,res)
;;   

(* exemples:

let l =  [1;2;6;24;720]
and div1 = (fun a b -> if a mod b =0 then a/b else failwith "div") 
and constant = (fun x -> x<2)
and zero = (fun x -> x=0)
;;

let f = facteurs_liste div1 constant l
;;

factorise_tableau div1 zero 0 (Array.of_list l) (Array.of_list f)
;;

*)


