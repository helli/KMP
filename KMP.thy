theory KMP
  imports "$AFP/Refine_Imperative_HOL/IICF/IICF"
    "~~/src/HOL/Library/Sublist"
begin

section\<open>Definition "substring"\<close>
  definition "is_substring_at' s t i \<equiv> take (length s) (drop i t) = s"  
  
  text\<open>Problem:\<close>
  value "is_substring_at' [] [a] 5"
  value "is_substring_at' [a] [a] 5"
  value "is_substring_at' [] [] 3"
  text\<open>Not very intuitive...\<close>
  
  text\<open>For the moment, we use this instead:\<close>
  fun is_substring_at :: "'a list \<Rightarrow> 'a list \<Rightarrow> nat \<Rightarrow> bool" where
    t1: "is_substring_at (s#ss) (t#ts) 0 \<longleftrightarrow> t=s \<and> is_substring_at ss ts 0" |
    t2: "is_substring_at ss (t#ts) (Suc i) \<longleftrightarrow> is_substring_at ss ts i" |
    "is_substring_at [] t 0 \<longleftrightarrow> True" |
    "is_substring_at _ [] _ \<longleftrightarrow> False"

  lemmas [code del] = t1 t2
    
  lemma [code]: "is_substring_at ss (t#ts) i \<longleftrightarrow> (if i=0 \<and> ss\<noteq>[] then t=hd ss \<and> is_substring_at (tl ss) ts 0 else is_substring_at ss ts (i-1))"  
    by (cases ss; cases i; auto)
  
  text\<open>For all relevant cases, both definitions agree:\<close>
  lemma "i \<le> length t \<Longrightarrow> is_substring_at s t i \<longleftrightarrow> is_substring_at' s t i"
    unfolding is_substring_at'_def
    by (induction s t i rule: is_substring_at.induct) auto
  
  text\<open>However, the new definition has some reasonable properties:\<close>
  lemma substring_length_s: "is_substring_at s t i \<Longrightarrow> length s \<le> length t"
    apply (induction s t i rule: is_substring_at.induct)
    apply simp_all
    done
  
  lemma substring_i: "is_substring_at s t i \<Longrightarrow> i \<le> length t - length s"
    apply (induction s t i rule: is_substring_at.induct)
    apply (auto simp add: Suc_diff_le substring_length_s)
    done
  
  text\<open>Furthermore, we need:\<close>
  
  lemma substring_step:
    "\<lbrakk>length s + i < length t; is_substring_at s t i; t!(i+length s) = x\<rbrakk> \<Longrightarrow> is_substring_at (s@[x]) t i"
    apply (induction s t i rule: is_substring_at.induct)
    apply auto
    using is_substring_at.elims(3) by fastforce
  
  lemma Nil_is_substring: "i \<le> length t \<Longrightarrow> is_substring_at [] t i"
    apply (induction t arbitrary: i)
    apply auto
    using is_substring_at.elims(3) by force
  
  lemma all_positions_substring:
  "\<lbrakk>length s \<le> length t; i \<le> length t - length s; \<forall>j'<length s. t!(i+j') = s!j'\<rbrakk> \<Longrightarrow> is_substring_at s t i"
  proof (induction s rule: rev_induct)
    case Nil
    then show ?case by (simp add: Nil_is_substring)
  next
    case (snoc x xs)
    from `length (xs @ [x]) \<le> length t` have "length xs \<le> length t" by simp
    moreover have "i \<le> length t - length xs"
      using snoc.prems(2) by auto
    moreover have "\<forall>j'<length xs. t ! (i + j') = xs ! j'"
      by (metis le_refl length_append less_le_trans nth_append snoc.prems(3) trans_le_add1)
    ultimately have f: "is_substring_at xs t i"
      using snoc.IH by blast
    show ?case
      apply (rule substring_step)
      using snoc.prems(1) snoc.prems(2) apply auto[1]
      apply (fact f)
      by (simp add: snoc.prems(3))
  qed
  
  lemma substring_all_positions:
    "is_substring_at s t i \<Longrightarrow> \<forall>j'<length s. t!(i+j') = s!j'"
    by (induction s t i rule: is_substring_at.induct)
      (auto simp: nth_Cons')
  
  text\<open>Another characterisation:\<close>
  fun slice :: "'a list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> 'a list" 
    where
    "slice (x#xs) (Suc n) l = slice xs n l"
  | "slice (x#xs) 0 (Suc l) = x # slice xs 0 l"  
  | "slice _ _ _ = []"  
  
  lemma slice_char_aux: "is_substring_at s t 0 \<longleftrightarrow> s = KMP.slice t 0 (length s)"
    apply (induction t arbitrary: s)
    subgoal for s by (cases s) auto  
    subgoal for _ _ s by (cases s) auto  
    done    
  
  lemma slice_char: "i\<le>length t \<Longrightarrow> is_substring_at s t i \<longleftrightarrow> s = slice t i (length s)"
    apply (induction s t i rule: is_substring_at.induct) 
    apply (auto simp: slice_char_aux)
    done
  
  (*Todo: fourth alternative: inductive is_substring_at*)

section\<open>Naive algorithm\<close>
subsection\<open>Basic form\<close>
  definition "I_out_na t s \<equiv> \<lambda>(i,j,found).
    \<not>found \<and> j = 0 \<and> (\<forall>i' < i. \<not>is_substring_at s t i')
    \<or> found \<and> is_substring_at s t i"
  definition "I_in_na t s iout (*KMP should need jout, too*) \<equiv> \<lambda>(j,found).
    \<not>found \<and> j < length s \<and> (\<forall>j' < j. t!(iout+j') = s!(j'))
    \<or> found \<and> j = length s \<and> is_substring_at s t iout"
  
  definition "na t s \<equiv> do {
    let i=0;
    let j=0;
    let found=False;
    (_,_,found) \<leftarrow> WHILEIT (I_out_na t s) (\<lambda>(i,j,found). i\<le>length t - length s \<and> \<not>found) (\<lambda>(i,j,found). do {
      (j,found) \<leftarrow> WHILEIT (I_in_na t s i) (\<lambda>(j,found). t!(i+j) = s!j \<and> \<not>found) (\<lambda>(j,found). do {
        let j=j+1;
        if j=length s then RETURN (j,True) else RETURN (j,False)
      }) (j,found);
      if \<not>found then do {
        let i = i + 1;
        let j = 0;
        RETURN (i,j,False)
      } else RETURN (i,j,True)
    }) (i,j,found);

    RETURN found
  }"
  
  lemma "\<lbrakk>s \<noteq> []; length s \<le> length t\<rbrakk>
    \<Longrightarrow> na t s \<le> SPEC (\<lambda>r. r \<longleftrightarrow> (\<exists>i. is_substring_at s t i))"
    unfolding na_def I_out_na_def I_in_na_def
    apply (refine_vcg 
          WHILEIT_rule[where R="measure (\<lambda>(i,_,found). (length t - i) + (if found then 0 else 1))"]
          WHILEIT_rule[where R="measure (\<lambda>(j,_::bool). length s - j)"]
          ) 
    apply (vc_solve solve: asm_rl)
    subgoal apply (metis all_positions_substring less_SucE) done
    subgoal using less_Suc_eq apply blast done
    subgoal by (metis less_SucE substring_all_positions)
    subgoal by (meson leI le_less_trans substring_i)
    done
  
  text\<open>These preconditions cannot be removed: If @{term \<open>s = []\<close>} (or @{term \<open>t = []\<close>}), the inner while-condition will access out-of-bound memory. The same can happen if @{term \<open>length t < length s\<close>} (I guess this one could be narrowed down to something like "if t is a proper prefix of s", but that's a bit pointless).\<close>
  
subsection\<open>A variant returning the position\<close>
  definition "I_out_nap t s \<equiv> \<lambda>(i,j,pos).
    (\<forall>i' < i. \<not>is_substring_at s t i') \<and>
    (case pos of None \<Rightarrow> j = 0
      | Some p \<Rightarrow> p=i \<and> is_substring_at s t i)"
  definition "I_in_nap t s iout \<equiv> \<lambda>(j,pos).
    case pos of None \<Rightarrow> j < length s \<and> (\<forall>j' < j. t!(iout+j') = s!(j'))
      | Some p \<Rightarrow> is_substring_at s t iout"

  definition "nap t s \<equiv> do {
    let i=0;
    let j=0;
    let pos=None;
    (_,_,pos) \<leftarrow> WHILEIT (I_out_nap t s) (\<lambda>(i,_,pos). i\<le>length t - length s \<and> pos=None) (\<lambda>(i,j,pos). do {
      (_,pos) \<leftarrow> WHILEIT (I_in_nap t s i) (\<lambda>(j,pos). t!(i+j) = s!j \<and> pos=None) (\<lambda>(j,_). do {
        let j=j+1;
        if j=length s then RETURN (j,Some i) else RETURN (j,None)
      }) (j,pos);
      if pos=None then do {
        let i = i + 1;
        let j = 0;
        RETURN (i,j,None)
      } else RETURN (i,j,Some i)
    }) (i,j,pos);

    RETURN pos
  }"
  
  lemma "\<lbrakk>s \<noteq> []; length s \<le> length t\<rbrakk>
    \<Longrightarrow> nap t s \<le> SPEC (\<lambda>None \<Rightarrow> \<nexists>i. is_substring_at s t i | Some i \<Rightarrow> is_substring_at s t i \<and> (\<forall>i'<i. \<not>is_substring_at s t i'))"
    unfolding nap_def I_out_nap_def I_in_nap_def
    apply (refine_vcg
      WHILEIT_rule[where R="measure (\<lambda>(i,_,pos). length t - i + (if pos = None then 1 else 0))"]
      WHILEIT_rule[where R="measure (\<lambda>(j,_::nat option). length s - j)"]
      )
    apply (vc_solve solve: asm_rl)
    apply (metis all_positions_substring less_antisym)
    using less_Suc_eq apply blast
    apply (metis less_SucE substring_all_positions)
    by (auto split: option.split intro: leI le_less_trans substring_i)

section\<open>Knuth–Morris–Pratt algorithm\<close>
subsection\<open>Auxiliary definitions\<close>
  text\<open>Borders of words\<close>
  definition "border r w \<longleftrightarrow> prefix r w \<and> suffix r w"
  
  lemma substring_unique: "\<lbrakk>is_substring_at s t i; is_substring_at s' t i; length s = length s'\<rbrakk> \<Longrightarrow> s = s'"
    by (metis nth_equalityI substring_all_positions)
  
  lemma border_length_r: "border r w \<Longrightarrow> length r \<le> length w"
    unfolding border_def by (simp add: prefix_length_le)
  
  lemma border_unique: "\<lbrakk>border r w; border r' w; length r = length r'\<rbrakk> \<Longrightarrow> r = r'"
    unfolding border_def by (metis order_mono_setup.refl prefix_length_prefix prefix_order.eq_iff)
  
  lemma border_lengths_differ: "\<lbrakk>border r w; border r' w; r\<noteq>r'\<rbrakk> \<Longrightarrow> length r \<noteq> length r'"
    using border_unique by auto
  
  lemma Nil_is_border[simp]: "border [] w"
    unfolding border_def by simp
  
  lemma border_length_r_less: "\<forall>r. r \<noteq> w \<and> border r w \<longrightarrow> length r < length w"
    unfolding border_def using not_equal_is_parallel prefix_length_le by fastforce
      
  lemma border_positions: "border r w \<Longrightarrow> \<forall>j<length r. w!j = w!(length w - length r + j)" unfolding border_def
    by (metis diff_add_inverse diff_add_inverse2 length_append not_add_less1 nth_append prefixE suffixE)
  
subsection\<open>Greatest and Least\<close>
  lemma GreatestM_natI2:
    fixes m::"_\<Rightarrow>nat"
    assumes "P x"
      and "\<forall>y. P y \<longrightarrow> m y < b"
      and "\<And>x. P x \<Longrightarrow> Q x"
    shows "Q (GreatestM m P)"
  by (fact GreatestM_natI[OF assms(1,2), THEN assms(3)])
  
  lemma Greatest_nat_Least:
    fixes m::"_\<Rightarrow>nat"
    assumes "\<forall>y. P y \<longrightarrow> m y \<le> b"
    shows "GreatestM m P = LeastM (\<lambda>a. b - m a) P"
    proof -
    have a: "(\<forall>y. P y \<longrightarrow> b - m x \<le> b - m y) \<longleftrightarrow> (\<forall>y. P y \<longrightarrow> m y \<le> m x)" for x
      using assms diff_le_mono2 by fastforce
    show ?thesis unfolding LeastM_def GreatestM_def a..
  qed
    
  lemma Least_nat_Greatest:
    fixes m::"_\<Rightarrow>nat"
    assumes "\<forall>y. P y \<longrightarrow> m y < b"
    shows "LeastM m P = GreatestM (\<lambda>a. b - m a) P"
  proof -
    have a: "(\<forall>y. P y \<longrightarrow> b - m y \<le> b - m x) \<longleftrightarrow> (\<forall>y. P y \<longrightarrow> m x \<le> m y)" for x
      using assms diff_le_mono2 by force
    show ?thesis unfolding LeastM_def GreatestM_def a..
  qed
  
  lemmas least_equality = some_equality[of "\<lambda>x. P x \<and> (\<forall>y. P y \<longrightarrow> m x \<le> m y)" for P m, folded LeastM_def, simplified]
  lemmas greatest_equality = some_equality[of "\<lambda>x. P x \<and> (\<forall>y. P y \<longrightarrow> m y \<le> m x)" for P m, folded GreatestM_def, no_vars]
  
  definition "intrinsic_border w \<equiv> GREATEST r WRT length . r\<noteq>w \<and> border r w"   
  
  definition "intrinsic_border' r w \<longleftrightarrow> border r w \<and> r\<noteq>w \<and>
    (\<nexists>r'. r'\<noteq>w \<and> border r' w \<and> length r < length r')"

  lemma ib'_ib: "w \<noteq> [] \<Longrightarrow> intrinsic_border' (intrinsic_border w) w"
  unfolding intrinsic_border_def intrinsic_border'_def
  apply (rule conjI)
    apply (rule GreatestM_natI2[of "\<lambda>r. r \<noteq> w \<and> border r w" "[]" length "length w"])
     apply (simp_all add: border_length_r_less)[3]
    apply (rule conjI)
    apply (rule GreatestM_natI2[of "\<lambda>r. r \<noteq> w \<and> border r w" "[]" length "length w"])
     apply (simp_all add: border_length_r_less)[3]
    apply auto
    using GreatestM_nat_le[OF _ border_length_r_less, of _ w]
    by (simp add: leD)
  
  lemma ib'_unique: "\<lbrakk>intrinsic_border' r w; intrinsic_border' r' w\<rbrakk> \<Longrightarrow> r = r'"
    by (metis border_unique intrinsic_border'_def nat_neq_iff)
  
  lemma ib'_length_r: "intrinsic_border' r w \<Longrightarrow> length r < length w"
    using border_length_r_less intrinsic_border'_def by blast
  
  lemma "needed?": "w \<noteq> [] \<Longrightarrow> let r = intrinsic_border w in r \<noteq> w \<and> border r w"
    unfolding intrinsic_border_def Let_def
    thm GreatestM_natI[of _ "[]"]
    apply (rule GreatestM_natI[of _ "[]"])
    using Nil_is_border apply blast
    using border_length_r_less apply auto
      done
  
  lemmas intrinsic_borderI = GreatestM_natI[of "\<lambda>r. r \<noteq> w \<and> border r w" "[]" length "length w", OF _ border_length_r_less, folded intrinsic_border_def, simplified] for w
  
  lemmas intrinsic_border_greatest = GreatestM_nat_le[of "\<lambda>r. r \<noteq> w \<and> border r w" _ length "length w", OF _ border_length_r_less, folded intrinsic_border_def] for w
  
  lemma intrinsic_border_less: "w \<noteq> [] \<Longrightarrow> length (intrinsic_border w) < length w"
    using intrinsic_borderI[of w] border_length_r_less by fastforce
  
  lemma intrinsic_border_less': "j > 0 \<Longrightarrow> w \<noteq> [] \<Longrightarrow> length (intrinsic_border (take j w)) < length w"
    by (metis intrinsic_border_less length_take less_not_refl2 min_less_iff_conj take_eq_Nil)
  
  text\<open>"Intrinsic border length plus one (only useful for @{term "s \<noteq> []"})"\<close>
  fun iblp1 :: "'a list \<Rightarrow> nat \<Rightarrow> nat" where
    "iblp1 s 0 = 0"(*by definition*) |
    "iblp1 s j = length (intrinsic_border (take j s)) + 1"
  (*Todo: Properties. They will need j \<le> length s*)
  
  lemma iblp1_j0: "iblp1 s j = 0 \<longleftrightarrow> j = 0"
    by (cases j) simp_all
  
  lemma iblp1_le: "s \<noteq> [] \<Longrightarrow> j \<le> length s \<Longrightarrow> iblp1 s j \<le> j"
    apply (cases j)
     apply simp_all
    by (metis (no_types, lifting) Suc_le_eq Suc_neq_Zero intrinsic_border_less leI length_take less_irrefl_nat less_le_trans min.absorb2 take_eq_Nil)
  
  lemma iblp1_le': "j > 0 \<Longrightarrow> s \<noteq> [] \<Longrightarrow> j \<le> length s \<Longrightarrow> iblp1 s j - 1 < j"
    using iblp1_j0 iblp1_le by fastforce
  
  lemma intrinsic_border_less'': "s \<noteq> [] \<Longrightarrow> j \<le> length s \<Longrightarrow> iblp1 s j - 1 < length s"
    by (cases j) (auto dest!: iblp1_le)
  
  lemma "p576 et seq":
    assumes
      "s \<noteq> []" "j \<le> length s" and
      assignments:
      "i' = i + (j + 1 - iblp1 s j)"
      "j' = max 0 (iblp1 s j - 1)"
    shows
      sum_no_decrease: "i' + j' \<ge> i + j" (*Todo: When needed? (≙Sinn von S.576?)*) and
      i_increase: "i' > i"
    using assignments by (auto simp: iblp1_le[OF assms(1-2), THEN le_imp_less_Suc])
  
  thm longest_common_prefix

subsection\<open>Invariants\<close>
  definition "I_outer t s \<equiv> \<lambda>(i,j,pos).
    (\<forall>i'<i. \<not>is_substring_at s t i') \<and>
    (case pos of None \<Rightarrow> (*j = 0*) (\<forall>j'<j. t!(i+j') = s!(j')) \<and> j < length s
      | Some p \<Rightarrow> p=i \<and> is_substring_at s t i)"
  definition "I_inner t s iout jout \<equiv> \<lambda>(j,pos). jout \<le> j \<and>
    (case pos of None \<Rightarrow> j < length s \<and> (\<forall>j'<j. t!(iout+j') = s!(j'))
      | Some p \<Rightarrow> is_substring_at s t iout)"
  
subsection\<open>Algorithm\<close>
  definition "kmp t s \<equiv> do {
    let i=0;
    let j=0;
    let pos=None;
    (_,_,pos) \<leftarrow> WHILEIT (I_outer t s) (\<lambda>(i,j,pos). i \<le> length t - length s \<and> pos=None) (\<lambda>(i,j,pos). do {
      (j,pos) \<leftarrow> WHILEIT (I_inner t s i j) (\<lambda>(j,pos). t!(i+j) = s!j \<and> pos=None) (\<lambda>(j,pos). do {
        let j=j+1;
        if j=length s then RETURN (j,Some i) else RETURN (j,None)
      }) (j,pos);
      if pos=None then do {
        let i = i + (j + 1 - iblp1 s j);
        let j = max 0 (iblp1 s j - 1); (*max not necessary*)
        RETURN (i,j,None)
      } else RETURN (i,j,Some i)
    }) (i,j,pos);

    RETURN pos
  }"
        
  lemma substring_substring:
    "\<lbrakk>is_substring_at s1 t i; is_substring_at s2 t (i + length s1)\<rbrakk> \<Longrightarrow> is_substring_at (s1@s2) t i"
    apply (induction s1 t i rule: is_substring_at.induct)
    apply auto
    done
  
  lemmas nth_stuff = nth_take nth_take_lemma nth_equalityI
  
  (*Todo: swap names, add i+\<dots>, decide whether w instead of x and w is enough*)
  lemma all_positions_drop_length_take: "\<lbrakk>i \<le> length w; i \<le> length x;
    \<forall>j<i. x ! j = w ! (length w + j - i)\<rbrakk>
      \<Longrightarrow> drop (length w - i) w = take i x"
    by (cases "i = length x") (simp_all add: nth_equalityI)
  
  lemma all_positions_suffix_take: "\<lbrakk>i \<le> length w; i \<le> length x;
    \<forall>j<i. x ! j = w ! (length w + j - i)\<rbrakk>
      \<Longrightarrow> suffix (take i x) w"
    by (metis all_positions_drop_length_take suffix_drop)
  
  thm suffix_drop take_is_prefix (* That naming -.- *)
  
  lemma border_take: "i \<le> length w \<Longrightarrow> \<forall>j<i. w!j = w!(length w - i + j)
    \<Longrightarrow> border (take i w) w" unfolding border_def
    by (metis all_positions_suffix_take add_diff_assoc2 take_is_prefix)
  
  lemma reuse_matches: 
    assumes thi: "0<j" True "j<length s" "\<forall>j'<j. t ! (i + j') = s ! j'"
    shows "\<forall>j'<iblp1 s j - 1. t ! (i + (Suc j - iblp1 s j) + j') = s ! j'"
  proof -
    from iblp1_le'[of j s] thi have "\<forall>j'<j. t ! (i + j') = s ! j'" by blast
    with thi have 1: "\<forall>j'<iblp1 s j - 1. t ! (i + j - iblp1 s j + 1 + j') = s ! (j - iblp1 s j + 1 + j')"
      by (smt Groups.ab_semigroup_add_class.add.commute Groups.semigroup_add_class.add.assoc add_diff_cancel_left' iblp1_le le_add_diff_inverse2 len_greater_imp_nonempty less_diff_conv less_or_eq_imp_le)
    have meh: "length (intrinsic_border (take j s)) = iblp1 s j - 1"
      by (metis KMP.iblp1.elims diff_add_inverse2 nat_neq_iff thi(1))
    from intrinsic_borderI[of "take j s"] border_positions[of "intrinsic_border (take j s)" "take j s", simplified]
    have "\<forall>ja<length (intrinsic_border (take j s)). take j s ! ja = take j s ! (min (length s) j - length (intrinsic_border (take j s)) + ja)"
      by (metis List.list.size(3) length_take less_numeral_extra(3) min_simps(2) thi(1) thi(3))
    then have "\<forall>ja<iblp1 s j - 1. take j s ! ja = take j s ! (j - (iblp1 s j - 1) + ja)"
      by (simp add: thi(3) meh)
    then have "\<forall>ja<iblp1 s j - 1. take j s ! ja = take j s ! (j - iblp1 s j + 1 + ja)"
      by (smt Groups.ab_semigroup_add_class.add.commute Groups.comm_monoid_add_class.add.comm_neutral One_nat_def Suc_diff_eq_diff_pred add_Suc_right diff_add_assoc diff_is_0_eq' gr_implies_not_zero iblp1_le len_greater_imp_nonempty less_eq_Suc_le less_or_eq_imp_le not_le thi(3))
    with thi have 2: "\<forall>j'<iblp1 s j - 1. s ! (j - iblp1 s j + 1 + j') = s ! j'"
      by (smt Groups.ab_semigroup_add_class.add.commute Groups.semigroup_add_class.add.assoc iblp1_le iblp1_le' le_add_diff_inverse2 le_less_trans less_diff_conv less_imp_le_nat nat_add_left_cancel_less nth_take take_eq_Nil)
    from 1 2 have "\<forall>j'<iblp1 s j - 1. t ! (i + (Suc j - iblp1 s j) + j') = s ! j'"
      by (smt Groups.semigroup_add_class.add.assoc Suc_diff_le Suc_eq_plus1 add_diff_assoc iblp1_le len_greater_imp_nonempty less_imp_le_nat thi(3))
    then show ?thesis.
  qed
  
  lemma shift_safe:
    assumes "length s \<le> length t"
      "\<forall>i'<i. \<not>is_substring_at s t i'"
      "t ! (i + j) \<noteq> s ! j"
      "i' < i + (Suc j - iblp1 s j)"
      "i \<le> length t - length s"
      "j < length s"
      "\<forall>j'<j. t ! (i + j') = s ! j'"
      "is_substring_at s t i'"
    shows False
      using assms oops
  
  lemma "\<lbrakk>s \<noteq> []; length s \<le> length t\<rbrakk>
    \<Longrightarrow> kmp t s \<le> SPEC (\<lambda>None \<Rightarrow> \<nexists>i. is_substring_at s t i | Some i \<Rightarrow> is_substring_at s t i \<and> (\<forall>i'<i. \<not>is_substring_at s t i'))"
    unfolding kmp_def I_outer_def I_inner_def
    apply (refine_vcg
      WHILEIT_rule[where R="measure (\<lambda>(i,_,pos). length t - i + (if pos = None then 1 else 0))"]
      WHILEIT_rule[where R="measure (\<lambda>(j,_::nat option). length s - j)"]
      )
    apply (vc_solve solve: asm_rl)
    subgoal for i jout j by (metis all_positions_substring less_SucE)
    using less_antisym apply blast
    subgoal for i jout j i' sorry
    subgoal for i jout j
      apply (cases "j=0")
      apply (simp_all add: reuse_matches intrinsic_border_less''[simplified])
      done
    subgoal for i _ j using i_increase[of s j _ i] by fastforce
    apply (auto split: option.split intro: leI le_less_trans substring_i)[]
    done

(*Todo: Algorithm for the set of all positions. Then: No break-flag needed.*)      
section\<open>Notes and Tests\<close>

  term "SPEC (\<lambda>x::nat. x \<in> {4,7,9})"
  
  term "RETURN (4::nat) = SPEC (\<lambda>x. x=4)" 
  
  definition "test \<equiv> do {
    x \<leftarrow> SPEC (\<lambda>x::nat. x<5);
    y \<leftarrow> SPEC (\<lambda>y. y<10);
    RETURN (x+y)
  }"  
  
  lemma "test \<le> SPEC (\<lambda>x. x<14)"
    unfolding test_def
    apply refine_vcg by auto  
  
  definition "i_test2 x\<^sub>0 \<equiv> \<lambda>(x,s). x\<ge>0 \<and> x\<^sub>0*5 = x*5+s"
  
  definition "test2 x\<^sub>0 \<equiv> do {
    (_,s) \<leftarrow> WHILEIT (i_test2 x\<^sub>0) (\<lambda>(x,s). x>0) (\<lambda>(x,s). do {
      let s = s + 5;
      let x = x - 1;
      RETURN (x,s)
    }) (x\<^sub>0::int,0::int);
    RETURN s
  }"
  
  lemma "x\<ge>0 \<Longrightarrow> test2 x \<le> SPEC (\<lambda>r. r=x*5)"
    unfolding test2_def i_test2_def
    apply (refine_vcg WHILEIT_rule[where R="measure (nat o fst)"])  
    apply auto
    done
  
section\<open>Examples\<close>
  lemma test: "intrinsic_border [] [z]"
    unfolding intrinsic_border_def border_def by simp (meson list_se_match(4) suffixE)
  
  lemma test2: "(\<some>w. intrinsic_border w [z]) = []"
    by (meson ib_unique someI test)
  
  lemma ex0: "border a '''' \<longleftrightarrow> a\<in>{
    ''''
    }"
    apply (auto simp: border_def slice_char_aux)
    done
    
  lemma ex1: "border a ''a'' \<longleftrightarrow> a\<in>{
    '''',
    ''a''
    }" unfolding border_def apply auto
      by (meson list_se_match(4) suffixE)
  
  lemma ex2: "border a ''aa'' \<longleftrightarrow> a\<in>{
    '''',
    ''a'',
    ''aa''
    }"
    apply (auto simp: border_def)
    apply (smt list.inject prefix_Cons prefix_bot.bot.extremum_uniqueI)
    by (simp add: suffix_ConsI)

  lemma ex3: "border a ''aab'' \<longleftrightarrow> a\<in>{
    '''',
    ''aab''
    }"
    apply (auto simp: border_def)
    using ex2 oops
    
  lemma ex7: "border a ''aabaaba'' \<longleftrightarrow> a\<in>{
    '''',
    ''a'',
    ''aaba'',
    ''aabaaba''}"
    apply (auto simp: border_def)
    oops
    
  lemma ex8: "border a ''aabaabaa'' \<longleftrightarrow> a\<in>{
    '''',
    ''a'',
    ''aa'',
    ''aabaa'',
    ''aabaabaa''}"
    apply (auto simp: border_def) oops

end
  (*Todo: rename is_substring_at so that it fits to the new HOL\List.thy. Arg_max is then available, too.*)
  (*Define and use strict_border ?*=
