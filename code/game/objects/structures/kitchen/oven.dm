/obj/structure/oven
	name = "Oven"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "oven"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	var/base_state = "oven"
	var/on = FALSE
	var/max_space = 7
	var/fuel = 0
	not_movable = FALSE
	not_disassemblable = FALSE
	var/consume_itself = FALSE
	var/looping = FALSE //for campfires
	var/cooking_time = 50

/obj/structure/oven/update_icon()
	if (on)
		icon_state = "[base_state]_on"
	else
		icon_state = base_state

/obj/structure/oven/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!istype(H))
		return

	if(istype(I, /obj/item/torch))
		return

	if (istype(I, /obj/item/weapon/reagent_containers/glass/small_pot))
		var/obj/item/weapon/reagent_containers/glass/small_pot/POT = I
		H << "You place the [POT] on top of the [src]."
		H.remove_from_mob(POT)
		POT.loc = src.loc
		POT.on_stove = TRUE
		return TRUE

	if (I.fuel_value)
		if(istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			H << "You place a chunk of \the [S] in \the [src], refueling it."
			fuel += S.fuel_value/70
			S.use(1)
			return
		fuel += I.amount*I.fuel_value/70
		H << "You place \the [I] in \the [src], refueling it."
		qdel(I)
		return

	if (istype(I, /obj/item/weapon/wrench) || (istype(I, /obj/item/weapon/hammer)))
		if (istype(I, /obj/item/weapon/wrench))
			visible_message("<span class='warning'>[H] starts to [anchored ? "unsecure" : "secure"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
			playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (do_after(H,50,src))
				visible_message("<span class='warning'>[H] [anchored ? "unsecures" : "secures"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
				anchored = !anchored
				return
		else if (istype(I, /obj/item/weapon/hammer))
			visible_message("<span class='warning'>[H] starts to deconstruct \the [src].</span>")
			playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (do_after(H,50,src))
				visible_message("<span class='warning'>[H] deconstructs \the [src].</span>")
				empty()
				qdel(src)
				return

	var/space = max_space
	for (var/obj/item/II in contents)
		space -= II.w_class
	if (space <= 0 || space - I.w_class < 0)
		H << "<span class = 'warning'>The [name] is full.</span>"
		return
	H.remove_from_mob(I)
	I.loc = src
	visible_message("<span class = 'notice'>[H] puts [I] in the [name].</span>")

// todo: fix eggs not roasting & roasted meat sandwiches turning to burnt mess
/obj/structure/oven/attack_hand(var/mob/living/human/H)
	if (!on && fuel > 0)
		visible_message("<span class = 'notice'>[H] turns the [name] on.</span>")
		on = TRUE
		ignition_source = TRUE
		fire_loop()
	else
		H << "<span class = 'warning'>The [name] doesn't have enough fuel! Fill it with wood or coal.</span>"

/obj/structure/oven/proc/fire_loop()
	if (on && fuel > 0)
		fuel -=1
		update_icon()
		if (name == "campfire")
			set_light(5)
		else if (name == "wood stove")
			set_light(2)
		else
			set_light(2)
		spawn (cooking_time)
			if (!looping)
				on = FALSE
				ignition_source = FALSE
				set_light(0)
				update_icon()
				if(prob(15))
					var byproduct = new/obj/item/stack/ore/charcoal
					contents += byproduct
			process()
			for (var/obj/item/weapon/reagent_containers/glass/small_pot/I in get_turf(src))
				if (istype(I, /obj/item/weapon/reagent_containers/glass/small_pot) && I.on_stove == TRUE)
					I.on_stove = FALSE
					I.reagents.del_reagent("food_poisoning")
					I.reagents.del_reagent("cholera")
					visible_message("<span class = 'notice'>\The [I] finishes boiling.</span>")
					if (I.reagents.get_reagent_amount("sodiumchloride")>0 && I.reagents.get_reagent_amount("water")>0)
						var/obj/item/weapon/reagent_containers/food/condiment/saltpile/empty/NSP = new /obj/item/weapon/reagent_containers/food/condiment/saltpile/empty(get_turf(src))
						NSP.reagents.add_reagent("sodiumchloride",I.reagents.get_reagent_amount("sodiumchloride"))
						I.reagents.del_reagent("sodiumchloride")
						I.reagents.del_reagent("water")
					if (I.reagents.get_reagent_amount("ash") > 0)
						var/ash_amnt = I.reagents.get_reagent_amount("ash")
						I.reagents.del_reagent("ash")
						I.reagents.add_reagent("lye", ash_amnt/5)
					if (I.reagents.get_reagent_amount("lard") > 0)
						var/lard_amnt = I.reagents.get_reagent_amount("lard")
						I.reagents.del_reagent("lard")
						I.reagents.add_reagent("fat_oil", lard_amnt/2)
			if (fuel <= 0 && consume_itself == TRUE)
				visible_message("<span class = 'warning'>\The [src] burns out.</span>")
				new/obj/item/stack/ore/charcoal(loc)
				qdel(src)

/obj/structure/oven/process()
	for (var/obj/item/I in contents)
		if (istype(I, /obj/item/stack/ore))
			if (istype(I, /obj/item/stack/ore/diamond))
				var/obj/item/stack/material/diamond/NO = new/obj/item/stack/material/diamond(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/glass))
				var/obj/item/stack/material/glass/NO = new/obj/item/stack/material/glass(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/dough))
			contents += new /obj/item/weapon/reagent_containers/food/snacks/sliceable/bread(src)
			contents -= I
			qdel(I)
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/cocoa))
			contents += new /obj/item/weapon/reagent_containers/food/snacks/chocolatebar(src)
			contents -= I
			qdel(I)
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/sliceable/flatdough))
			contents += new /obj/item/weapon/reagent_containers/food/snacks/flatbread(src)
			contents -= I
			qdel(I)
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawsticks))
			contents += new /obj/item/weapon/reagent_containers/food/snacks/fries(src)
			contents -= I
			qdel(I)
		else if (istype(I, /obj/item/weapon/clay))
			var/obj/item/weapon/clay/CL = I
			contents += new CL.result(src)
			if (CL.result == /obj/item/weapon/clay/claybricks/fired)
				contents += new CL.result(src)
			contents -= I
			qdel(I)

		else if (!istype(I, /obj/item/weapon/reagent_containers/food) || istype(I, /obj/item/weapon/reagent_containers/food/drinks) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/badrecipe) || I.name == "Stew" || findtext(I.name, "soup") || (I.vars.Find("roasted") && I:roasted))
			if (!istype(I, /obj/item/organ))
				contents += new /obj/item/weapon/reagent_containers/food/snacks/badrecipe(src)
				contents -= I
				qdel(I)
			else
				var/obj/item/weapon/reagent_containers/food/snacks/organ/organ = new /obj/item/weapon/reagent_containers/food/snacks/organ(src)
				organ.name = "roasted [I.name]"
				organ.desc = I.desc
				organ.icon = I.icon
				organ.icon_state = I.icon_state
				organ.color = "#E59400"
				organ.reagents.multiply_reagent("nutriment", 5)
				organ.reagents.multiply_reagent("protein", 3)
				organ.reagents.del_reagent("toxin")
				organ.reagents.del_reagent("cholera")
				organ.reagents.del_reagent("food_poisoning")
				organ.roasted = TRUE
				contents -= I
				qdel(I)

		else
			I.name = replacetext(I.name, "raw ", "")
			I.desc = replacetext(I.desc, "raw", "roasted")
			I.name = "roasted [I.name]"
			I.color = "#E59400"
			I.reagents.multiply_reagent("nutriment", 5)
			I.reagents.multiply_reagent("protein", 3)
			I.reagents.del_reagent("food_poisoning")
			I.reagents.del_reagent("cholera")
			if (istype(I, /obj/item/weapon/reagent_containers/food))
				var/obj/item/weapon/reagent_containers/food/F = I
				F.roasted = TRUE
				F.raw = FALSE
				if (!F.disgusting)
					F.satisfaction = abs(F.satisfaction*2)
				else
					F.satisfaction *= 0.75

	for (var/obj/item/I in contents)
		I.loc = get_turf(src)

/obj/structure/oven/verb/empty()
	set category = null
	set name = "Empty"
	set src in range(1, usr)
	for (var/obj/item/I in contents)
		I.loc = get_turf(src)

/obj/structure/oven/woodstove
	name = "wood stove"
	desc = "A stove fueled with wood logs."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "woodstove"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "woodstove"
	on = FALSE
	max_space = 9
	fuel = 4

/obj/structure/oven/stove
	name = "stove"
	desc = "A stove that runs on electricity."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "stove"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "stove"
	on = FALSE
	max_space = 12
	fuel = 4

/obj/structure/oven/stove/old
	icon_state = "gasstove"

/obj/structure/oven/grill
	name = "metal grill"
	desc = "A grill with a raised inner fire-pit for refuelling."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "grill"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "grill"
	on = FALSE
	max_space = 4
	fuel = 0

//////////////////Following objects are grill or oven subtypes until proper cooking/kitchen mechanics will be implemented

/obj/structure/oven/grill/gas
	name = "gas grill"
	desc = "A gas-fueled grill."
	icon_state = "grill2"
	base_state = "grill2"

/obj/structure/oven/griddle
	name = "electric griddle"
	desc = "A heavy, flat iron plate that is heated and used for cooking food."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "griddle"
	layer = 3
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "griddle"
	on = FALSE
	max_space = 12
	fuel = 4

/obj/structure/oven/fryer
	name = "fryer"
	desc = "A large, deep container for frying food."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "fryer"
	layer = 3
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "fryer"
	on = FALSE
	max_space = 4
	fuel = 0