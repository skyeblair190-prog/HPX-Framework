return {
	['testburger'] = {
		label = 'Test Burger',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'what an amazingly delicious burger, amirite?'
		},
		buttons = {
			{
				label = 'Lick it',
				action = function(slot)
					print('You licked the burger')
				end
			},
			{
				label = 'Squeeze it',
				action = function(slot)
					print('You squeezed the burger :(')
				end
			},
			{
				label = 'What do you call a vegan burger?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('A misteak.')
				end
			},
			{
				label = 'What do frogs like to eat with their hamburgers?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('French flies.')
				end
			},
			{
				label = 'Why were the burger and fries running?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('Because they\'re fast food.')
				end
			}
		},
		consume = 0.3
	},

	['bandage'] = {
		label = 'Bandage',
		weight = 115,
		client = {
			anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
			prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
			disable = { move = true, car = true, combat = true },
			usetime = 2500,
		}
	},

	['black_money'] = {
		label = 'Dirty Money',
	},

	['burger'] = {
		label = 'Burger',
		weight = 220,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			notification = 'You ate a delicious burger'
		},
	},

	['sprunk'] = {
		label = 'Sprunk',
		weight = 350,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
			usetime = 2500,
			notification = 'You quenched your thirst with a sprunk'
		}
	},

	['parachute'] = {
		label = 'Parachute',
		weight = 8000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'Garbage',
	},

	['paperbag'] = {
		label = 'Paper Bag',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['identification'] = {
		label = 'Identification',
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'Knickers',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	['lockpick'] = {
		label = 'Lockpick',
		weight = 160,
	},

	['phone'] = {
		label = 'Phone',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['money'] = {
		label = 'Money',
	},

	['mustard'] = {
		label = 'Mustard',
		weight = 500,
		client = {
			status = { hunger = 25000, thirst = 25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
			usetime = 2500,
			notification = 'You.. drank mustard'
		}
	},

	['water'] = {
		label = 'Water',
		weight = 500,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 2500,
			cancel = true,
			notification = 'You drank some refreshing water'
		}
	},

	['radio'] = {
		label = 'Radio',
		weight = 1000,
		stack = false,
		allowArmed = true
	},

	['armour'] = {
		label = 'Bulletproof Vest',
		weight = 3000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = 'Clothing',
		consume = 0,
	},

	['mastercard'] = {
		label = 'Fleeca Card',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['giftcard'] = {
		label = 'Gift Card',
		weight = 10,
	},

	['scrapmetal'] = {
		label = 'Scrap Metal',
		weight = 80,
	},

	['newskit'] = {
		label = 'News Kit',
		weight = 500,
	},

	['laptopnews'] = {
		label = 'News Laptop',
		weight = 1500,
	},

	['paper'] = {
		label = 'Paper',
		weight = 10,
	},

	['printer'] = {
		label = 'Printer',
		weight = 2500,
	},

	['bank_card'] = {
		label = 'Bank Card',
		weight = 10,
		stack = false,
		close = false,
		description = 'A bank card linked to your account.',
	},

	['atm_receipt'] = {
		label = 'ATM Receipt',
		weight = 10,
		stack = false,
		description = 'A receipt from the ATM.',
		client = {
			image = 'atm_receipt.png',
		},
		server = {
			export = 'hpx_banking.use_atm_receipt',
		},
	},

	['codera_tablet'] = {
		label = 'Work Tablet',
		weight = 700,
		stack = false,
		close = true,
		description = 'A tablet with job and utility apps.',
		client = {
			event = 'codera-tablet:openTablet',
		},
	},

	['ugchip'] = {
		label = 'Underground Chip',
		weight = 50,
		description = 'Unlocks restricted tablet applications.',
	},

	['phone_black'] = {
		label = 'Phone (Black)',
		weight = 190,
		stack = false,
		close = true,
		description = 'A smartphone.',
	},

	['phone_blue'] = {
		label = 'Phone (Blue)',
		weight = 190,
		stack = false,
		close = true,
		description = 'A smartphone.',
	},

	['phone_green'] = {
		label = 'Phone (Green)',
		weight = 190,
		stack = false,
		close = true,
		description = 'A smartphone.',
	},

	['phone_orange'] = {
		label = 'Phone (Orange)',
		weight = 190,
		stack = false,
		close = true,
		description = 'A smartphone.',
	},

	['phone_pink'] = {
		label = 'Phone (Pink)',
		weight = 190,
		stack = false,
		close = true,
		description = 'A smartphone.',
	},

	['phone_purple'] = {
		label = 'Phone (Purple)',
		weight = 190,
		stack = false,
		close = true,
		description = 'A smartphone.',
	},

	['phone_red'] = {
		label = 'Phone (Red)',
		weight = 190,
		stack = false,
		close = true,
		description = 'A smartphone.',
	},

	['phone_yellow'] = {
		label = 'Phone (Yellow)',
		weight = 190,
		stack = false,
		close = true,
		description = 'A smartphone.',
	},

	['sim_card'] = {
		label = 'SIM Card',
		weight = 5,
		stack = false,
		description = 'Holds a phone number.',
	},
}
