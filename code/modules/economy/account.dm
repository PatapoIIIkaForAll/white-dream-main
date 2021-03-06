#define DUMPTIME 3000

/datum/bank_account
	var/account_holder = "Rusty Venture"
	var/account_balance = 0
	var/payday_modifier
	var/datum/job/account_job
	var/list/bank_cards = list()
	var/add_to_accounts = TRUE
	var/account_id
	var/being_dumped = FALSE //pink levels are rising

/datum/bank_account/New(newname, job, modifier = 1)
	if(add_to_accounts)
		SSeconomy.bank_accounts += src
	account_holder = newname
	account_job = job
	account_id = rand(111111,999999)
	payday_modifier = modifier

/datum/bank_account/Destroy()
	if(add_to_accounts)
		SSeconomy.bank_accounts -= src
	return ..()

/datum/bank_account/proc/dumpeet()
	being_dumped = TRUE

/datum/bank_account/proc/_adjust_money(amt)
	account_balance += amt
	if(account_balance < 0)
		account_balance = 0

/datum/bank_account/proc/has_money(amt)
	return account_balance >= amt

/datum/bank_account/proc/adjust_money(amt)
	if((amt < 0 && has_money(-amt)) || amt > 0)
		_adjust_money(amt)
		return TRUE
	return FALSE

/datum/bank_account/proc/transfer_money(datum/bank_account/from, amount)
	if(from.has_money(amount))
		adjust_money(amount)
		SSblackbox.record_feedback("amount", "credits_transferred", amount)
		log_econ("[amount] credits were transferred from [from.account_holder]'s account to [src.account_holder]")
		from.adjust_money(-amount)
		return TRUE
	return FALSE

/datum/bank_account/proc/payday(amt_of_paychecks, free = FALSE)
	var/money_to_transfer = account_job.paycheck * payday_modifier * amt_of_paychecks
	if(free)
		adjust_money(money_to_transfer)
		SSblackbox.record_feedback("amount", "free_income", money_to_transfer)
		log_econ("[money_to_transfer] credits were given to [src.account_holder]'s account from income.")
	else
		var/datum/bank_account/D = SSeconomy.get_dep_account(account_job.paycheck_department)
		if(D)
			if(!transfer_money(D, money_to_transfer))
				bank_card_talk("ERROR: Зарплата отменена. Недостаточно средстве на счету отдела.")
				return FALSE
			else
				bank_card_talk("Зарплата выдана, текущий баланс: [account_balance] кр.")
				return TRUE
	bank_card_talk("ERROR: Зарплата не выдана. Невозможно связаться с аккаунтом отдела.")
	return FALSE

/datum/bank_account/proc/bank_card_talk(message, force)
	if(!message || !bank_cards.len)
		return
	for(var/obj/A in bank_cards)
		var/mob/card_holder = recursive_loc_check(A, /mob)
		if(ismob(card_holder)) //If on a mob
			if(!card_holder.client || (!(card_holder.client.prefs.chat_toggles & CHAT_BANKCARD) && !force))
				return

			if(card_holder.can_hear())
				card_holder.playsound_local(get_turf(card_holder), 'sound/machines/twobeep_high.ogg', 50, TRUE)
				to_chat(card_holder, "<span class='notice'><b>Карта:</b> [message]</span>")
		else if(isturf(A.loc)) //If on the ground
			var/turf/T = A.loc
			for(var/mob/M in hearers(1,T))
				if(!M.client || (!(M.client.prefs.chat_toggles & CHAT_BANKCARD) && !force))
					continue
				if(M.can_hear())
					M.playsound_local(T, 'sound/machines/twobeep_high.ogg', 50, TRUE)
					to_chat(M, "<span class='notice'><b>Карта:</b> [message]</span>")
		else
			var/atom/sound_atom
			for(var/mob/M in A.loc) //If inside a container with other mobs (e.g. locker)
				if(!M.client || (!(M.client.prefs.chat_toggles & CHAT_BANKCARD) && !force))
					continue
				if(!sound_atom)
					sound_atom = A.drop_location() //in case we're inside a bodybag in a crate or something. doing this here to only process it if there's a valid mob who can hear the sound.
				if(M.can_hear())
					M.playsound_local(get_turf(sound_atom), 'sound/machines/twobeep_high.ogg', 50, TRUE)
					to_chat(M, "<span class='notice'><b>Карта:</b> [message]</span>")

/datum/bank_account/department
	account_holder = "Guild Credit Agency"
	var/department_id = "REPLACE_ME"
	add_to_accounts = FALSE

/datum/bank_account/department/New(dep_id, budget)
	department_id = dep_id
	account_balance = budget
	account_holder = SSeconomy.department_accounts[dep_id]
	SSeconomy.generated_accounts += src

/datum/bank_account/remote // Bank account not belonging to the local station
	add_to_accounts = FALSE

#undef DUMPTIME
