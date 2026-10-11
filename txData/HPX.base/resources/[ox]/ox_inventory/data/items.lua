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

	-- md-drugs items
	['weed_skunk_seed'] = {
        label = 'Skunk Seed',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_seed.png" 
         },
    },
	['weed_ogkush_seed'] = {
        label = 'OG Kush Seed',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_seed.png" 
         },
    },
	['weed_amnesia_seed'] = {
        label = 'Amensia Seed',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_seed.png" 
         },
    },
	['weed_ak47_seed'] = {
        label = 'AK47 Seed',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_seed.png" 
         },
    },
	['weed_purplehaze_seed'] = {
        label = 'Purple Haze Seed',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_seed.png" 
         },
    },
	['weed_whitewidow_seed'] = {
        label = 'White Widow Seed',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_seed.png" 
         },
    },
	['weed_whitewidow'] = {
        label = 'White Widow 2g',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_baggy.png" 
         },
    },
	['weed_skunk'] = {
        label = 'Skunk 2g',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_baggy.png" 
         },
    },
	['weed_purplehaze'] = {
        label = 'Purple Haze 2g',
        weight = 200,
        stack = true,
        close = false,
        client = { 
           image = "weed_baggy.png" 
         },
    },
	['weed_ogkush'] = {
      label = 'OG Kush 2g',
      weight = 200,
      stack = true,
      close = false,
      client = { 
         image = "weed_baggy.png" 
       },
    },
	['weed_amnesia'] = {
      label = 'Amnesia 2g',
      weight = 200,
      stack = true,
      close = false,
      client = { 
         image = "weed_baggy.png" 
       },
    },
	['weed_ak47'] = {
      label = 'AK47 2g',
      weight = 200,
      stack = true,
      close = false,
      client = { 
         image = "weed_baggy.png" 
       },
    },
	['coke'] = {
        label = 'Raw Cocaine',
        weight = 1000,
        stack = true,
        close = false,
        client = { 
           image = "coke.png" 
         },
    },
	['coca_leaf'] = {
        label = 'Cocaine leaves',
        weight = 1500,
        stack = true,
        close = false,
        client = { 
           image = "coca_leaf.png" 
         },
    },
	['bakingsoda'] = {
        label = 'Baking Soda',
        weight = 300,
        stack = true,
        close = false,
        client = { 
           image = "bakingsoda.png" 
         },
    },
	['loosecoke'] = {
        label = 'Loose Coke',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'loosecoke.png' 
         },
    },
	['loosecokestagetwo'] = {
        label = 'Loose Coke',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'loosecokestagetwo.png' 
         },
    },
	['loosecokestagethree'] = {
        label = 'Loose Coke',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'loosecokestagethree.png' 
         },
    },
	['cokebaggy'] = {
        label = 'Bag of Cocaine',
        weight = 0,
        stack = true,
        close = true,
        client = { 
           image = 'cocaine_baggy.png' 
         },
    },
	['cokebaggystagetwo'] = {
        label = 'Bag Of Cocaine',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'cocaine_baggystagetwo.png' 
         },
    },
	['cokebaggystagethree'] = {
        label = 'Bag Of Cocaine',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'cocaine_baggystagethree.png' 
         },
    },
	['cokestagetwo'] = {
        label = 'Raw Cocaine',
        weight = 100,
        stack = true,
        close = false,
        client = { 
           image = "cokestagetwo.png" 
         },
    },
	['cokestagethree'] = {
        label = 'Raw Cocaine',
        weight = 100,
        stack = true,
        close = false,
        client = { 
           image = "cokestagethree.png" 
         },
    },
	['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        weight = 0,
        stack = true,
        close = true,
        client = { 
           image = 'weed_baggy_empty.png' 
         },
    },
	['bakingsoda'] = {
        label = 'Baking Soda',
        weight = 300,
        stack = true,
        close = false,
        client = { 
           image = "bakingsoda.png" 
         },
    },
	['baggedcracked'] = {
        label = 'Bag Of Crack',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "crackbag1.png" 
         },
    },
	['baggedcrackedstagetwo'] = {
        label = 'Better Bag Of Crack',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "crackbag2.png" 
         },
    },
	['baggedcrackedstagethree'] = {
        label = 'Best Bag Of Crack',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "crackbag3.png" 
         },
    },
	['crackrock'] = {
        label = 'Crack Rock',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "crackrock1.png" 
         },
    },
	['crackrockstagetwo'] = {
        label = 'Better Crack Rock',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "crackrock2.png" 
         },
    },
	['crackrockstagethree'] = {
        label = 'Best Crack Rock',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "crackrock3.png" 
         },
    },
	['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        weight = 0,
        stack = true,
        close = true,
        client = { 
           image = 'weed_baggy_empty.png' 
         },
    },
	['bakingsoda'] = {
        label = 'Baking Soda',
        weight = 300,
        stack = true,
        close = false,
        client = { 
           image = "bakingsoda.png" 
         },
    },
	['poppyresin'] = {
        label = 'Poppy resin',
        weight = 2000,
        stack = true,
        close = false,
        client = { 
           image = "poppyresin.png" 
         },
    },
	['heroin'] = {
        label = 'Heroin Powder',
        weight = 500,
        stack = true,
        close = false,
        client = { 
           image = "heroinpowder.png" 
         },
    },
	['heroinstagetwo'] = {
        label = 'Heroin Powder',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroinpowderstagetwo.png" 
         },
    },
	['heroinstagethree'] = {
        label = 'Heroin Powder',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroinpowderstagethree.png" 
         },
    },
	['heroincut'] = {
        label = 'Cut Heroin',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroincut.png" 
         },
    },
	['heroincutstagetwo'] = {
        label = 'Cut Heroin',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroincut2.png" 
         },
    },
	['heroincutstagethree'] = {
        label = 'Cut Heroin',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroincut3.png" 
         },
    },
	['heroinlabkit'] = {
        label = 'Heroin Lab Kit',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "labkit.png" 
         },
    },
	['heroinvial'] = {
        label = 'Vial Of Heroin',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroin.png" 
         },
    },
	['heroinvialstagetwo'] = {
        label = 'Vial of Heroin',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroinstagetwo.png" 
         },
    },
	['heroinvialstagethree'] = {
        label = 'Vial Of Heroin',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroinstagethree.png" 
         },
    },
	['heroin_ready'] = {
        label = 'Heroin Syringe',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroin_ready.png" 
         },
    },
	['heroin_readystagetwo'] = {
        label = 'Heroin Syringe',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroin_readystagetwo.png" 
         },
    },
	['heroin_readystagethree'] = {
        label = 'Heroin Syringe',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "heroin_readystagethree.png" 
         },
    },
	['emptyvial'] = {
        label = 'empty vial',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "emptyvial.png" 
         },
    },
	['needle'] = {
        label = 'Syringe',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "syringe.png" 
         },
    },
	['leancup'] = {
        label = 'Empty Cup',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "leancup.png" 
         },
    },
	['cupoflean'] = {
        label = 'Lean Cup',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "cupoflean.png" 
         },
    },
	['cupofdextro'] = {
        label = 'Dextro Cup',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "cupofdextro.png" 
         },
    },
	['mdlean'] = {
        label = 'Sizzurup',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "Sizzurup.png" 
         },
    },
	['mdreddextro'] = {
        label = 'Red Dextro',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "reddextro.png" 
         },
    },
	['lysergic_acid'] = {
        label = 'Lysergic Acid',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'lysergic_acid.png' 
         },
    },
	['diethylamide'] = {
        label = 'Diethylamide',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'diethylamide.png' 
         },
    },
	['lsd_one_vial'] = {
        label = 'Tier 1 LSD Vial',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'lsd_one_vial.png' 
         },
    },
	['lsd_vial_two'] = {
        label = 'Tier 2 LSD Vial',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'lsd_vial_two.png' 
         },
    },
	['lsd_vial_three'] = {
        label = 'Tier 3 LSD Vial',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'lsd_vial_three.png' 
         },
    },
	['lsd_vial_four'] = {
        label = 'Tier 4 LSD Vial',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'lsd_vial_four.png' 
         },
    },
	['lsd_vial_five'] = {
        label = 'Tier 5 LSD Vial',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'lsd_vial_five.png' 
         },
    },
	['lsd_vial_six'] = {
        label = 'Tier 6 LSD Vial',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'lsd_vial_six.png' 
         },
    },
	['tab_paper'] = {
        label = 'Tab Paper',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'tab_paper.png' 
         },
    },
	['smileyfacesheet'] = {
        label = 'Smiley Face Sheet',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'smileysheet.png' 
         },
    },
	['wildcherrysheet'] = {
        label = 'Wild Cherry Sheet',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'wildcherrysheet.png' 
         },
    },
	['yinyangsheet'] = {
        label = 'Yin and Yang Sheet',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'yinyangsheet.png' 
         },
    },
	['pineapplesheet'] = {
        label = 'Pineapple Sheet',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'pineapplesheet.png' 
         },
    },
	['bart_tabs'] = {
        label = 'Cluckin Tabs',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'bart_tabs.png' 
         },
    },
	['bartsheet'] = {
        label = 'Cluckin Sheet',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'bartsheet.png' 
         },
    },
	['gratefuldeadsheet'] = {
        label = 'Maze Sheet',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'gratefuldeadsheet.png' 
         },
    },
	['smiley_tabs'] = {
        label = 'Smiley tabs',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'smiley_tabs.png' 
         },
    },
	['wildcherry_tabs'] = {
        label = 'Wild Cherry Tabs',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'wildcherry_tabs.png' 
         },
    },
	['yinyang_tabs'] = {
        label = 'Yin and Yang Tabs',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'yinyang_tabs.png' 
         },
    },
	['pineapple_tabs'] = {
        label = 'Pineapple Tabs',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'pineapple_tabs.png' 
         },
    },
	['gratefuldead_tabs'] = {
        label = 'Maze Tabs',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'gratefuldead_tabs.png' 
         },
    },
	['lsdlabkit'] = {
        label = 'LSD Mixing Table',
        weight = 1000,
        stack = true,
        close = true,
        client = { 
           image = 'labkit.png' 
         },
    },
	['cactusbulb'] = {
        label = 'Cactus Bulb',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "cactusbulb.png" 
         },
    },
	['driedmescaline'] = {
        label = 'Mescaline',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "driedmescaline.png" 
         },
    },
	['ephedrine'] = {
        label = 'Ephedrine',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "ephedrine.png" 
         },
    },
	['acetone'] = {
        label = 'Acetone',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "acetone.png" 
         },
    },
	['methbags'] = {
        label = 'Meth',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "methbags.png" 
         },
    },
	['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        weight = 0,
        stack = true,
        close = true,
        client = { 
           image = 'weed_baggy_empty.png' 
         },
    },
	['prescription_pad'] = {
        label = 'Prescription Pad',
        weight = 10,
        stack = true,
        close = false,
        client = { 
           image = 'prescriptionpad.png' 
         },
    },
	['vicodin_prescription'] = {
        label = 'Vicie Prescription',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "adderalprescription.png" 
         },
    },
	['adderal_prescription'] = {
        label = 'Mdderal Prescription',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "adderalprescription.png" 
         },
    },
	['morphine_prescription'] = {
        label = 'Morphin Prescription',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "adderalprescription.png" 
         },
    },
	['xanax_prescription'] = {
        label = 'Zany Prescription',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "adderalprescription.png" 
         },
    },
	['adderal'] = {
        label = 'Madderal',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'adderal.png' 
         },
    },
	['vicodin'] = {
        label = 'Vicie',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'vicodin.png' 
         },
    },
	['morphine'] = {
        label = 'Morphin',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'morphine.png' 
         },
    },
	['xanax'] = {
        label = 'Zany',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'xanax.png' 
         },
    },
	['adderalbottle'] = {
        label = 'Madderal Bottle',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'pillbottle.png' 
         },
    },
	['vicodinbottle'] = {
        label = 'Vicie Bottle',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'pillbottle.png' 
         },
    },
	['morphinebottle'] = {
        label = 'Morphin Bottle',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'pillbottle.png' 
         },
    },
	['xanaxbottle'] = {
        label = 'Zany Bottle',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'pillbottle.png' 
         },
    },
	['shrooms'] = {
        label = 'Shrooms',
        weight = 250,
        stack = true,
        close = false,
        client = { 
           image = "shrooms.png" 
         },
    },
	['wetcannabis'] = {
        label = 'Wet Cannabis',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "wetcannabis.png" 
         },
    },
	['drycannabis'] = {
        label = 'Dry Cannabis',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "driedcannabis.png" 
         },
    },
	['weedgrinder'] = {
        label = 'Weed Grinder',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "weedgrinder.png" 
         },
    },
	['mdbutter'] = {
        label = 'Butter',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "butter.png" 
         },
    },
	['cannabutter'] = {
        label = 'Canna-Butter',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "cannabutter.png" 
         },
    },
	['specialbrownie'] = {
        label = 'Special Brownie',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "specialbrownie.png" 
         },
    },
	['specialcookie'] = {
        label = 'Special Cookie',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "specialcookie.png" 
         },
    },
	['specialmuffin'] = {
        label = 'Special Muffin',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "specialmuffin.png" 
         },
    },
	['specialchocolate'] = {
        label = 'Special Chocolate',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "specialchocolate.png" 
         },
    },
	['grindedweed'] = {
        label = 'Keef',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "keef.png" 
         },
    },
	['flour'] = {
        label = 'Flour',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "flour.png" 
         },
    },
	['chocolate'] = {
        label = 'Chocolate',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "chocolate.png" 
         },
    },
	['blunt'] = {
        label = 'Blunts',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "blunt.png" 
         },
    },
	['butane'] = {
        label = 'Butane',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "butane.png" 
         },
    },
	['butanetorch'] = {
        label = 'Butane Torch',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "butanetorch.png" 
         },
    },
	['dabrig'] = {
        label = 'Dab Rig',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "dabrig2.png" 
         },
    },
	['mdwoods'] = {
        label = 'MDWOODS',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "mdwoods.png" 
         },
    },
	['ciggie'] = {
        label = 'Ciggie',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "ciggie.png" 
         },
    },
	['tobacco'] = {
        label = 'Tobacco',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "tobacco.png" 
         },
    },
	['shatter'] = {
        label = 'Shatter',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "shatter.png" 
         },
    },
	['bluntwrap'] = {
        label = 'Blunt Wrap',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "bluntwrap.png" 
         },
    },
	['leanbluntwrap'] = {
        label = 'Lean Blunt Wrap',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "leanbluntwrap.png" 
         },
    },
	['dextrobluntwrap'] = {
        label = 'Dextro Blunt Wrap',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "dextrobluntwrap.png" 
         },
    },
	['leanblunts'] = {
        label = 'Lean Blunts',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "leanblunts.png" 
         },
    },
	['dextroblunts'] = {
        label = 'Dextro Blunts',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "dextroblunts.png" 
         },
    },
	['chewyblunt'] = {
        label = 'Chewy',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "blunt.png" 
         },
    },
	['cokeburner'] = {
        label = 'Coke Burner',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "gta5phone.png" 
         },
    },
	['crackburner'] = {
        label = 'Crack Burner',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "gta5phone.png" 
         },
    },
	['heroinburner'] = {
        label = 'Heroin Burner',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "gta5phone.png" 
         },
    },
	['lsdburner'] = {
        label = 'LSD Burner',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "gta5phone.png" 
         },
    },
	['xtcburner'] = {
        label = 'XTC Burner',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "gta5phone.png" 
         },
    },
	['isosafrole'] = {
        label = 'isosafrole',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'isosafrole.png' 
         },
    },
	['mdp2p'] = {
        label = 'mdp2p',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = 'mdp2p.png' 
         },
    },
	['raw_xtc'] = {
        label = 'Raw XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "raw_xtc.png" 
         },
    },
	['singlepress'] = {
        label = 'Single Pill Press',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "pillpress.png" 
         },
    },
	['dualpress'] = {
        label = 'Dual Pill Press',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "pillpress.png" 
         },
    },
	['triplepress'] = {
        label = 'Triple Pill Press',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "pillpress.png" 
         },
    },
	['quadpress'] = {
        label = 'Quad Pill Press',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "pillpress.png" 
         },
    },
	['white_xtc'] = {
        label = 'White XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_white.png" 
         },
    },
	['white_xtc2'] = {
        label = 'White XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_white2.png" 
         },
    },
	['white_xtc3'] = {
        label = 'White XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_white3.png" 
         },
    },
	['white_xtc4'] = {
        label = 'White XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_white4.png" 
         },
    },
	['red_xtc'] = {
        label = 'Red XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_red.png" 
         },
    },
	['red_xtc2'] = {
        label = 'Red XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_red2.png" 
         },
    },
	['red_xtc3'] = {
        label = 'Red XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_red3.png" 
         },
    },
	['red_xtc4'] = {
        label = 'Red XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_red4.png" 
         },
    },
	['orange_xtc'] = {
        label = 'Orange XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_orange.png" 
         },
    },
	['orange_xtc2'] = {
        label = 'Orange XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_orange2.png" 
         },
    },
	['orange_xtc3'] = {
        label = 'Orange XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_orange3.png" 
         },
    },
	['orange_xtc4'] = {
        label = 'Orange XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_orange4.png" 
         },
    },
	['blue_xtc'] = {
        label = 'Blue XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_blue.png" 
         },
    },
	['blue_xtc2'] = {
        label = 'Blue XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_blue2.png" 
         },
    },
	['blue_xtc3'] = {
        label = 'Blue XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_blue3.png" 
         },
    },
	['blue_xtc4'] = {
        label = 'Blue XTC',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "unstamped_blue4.png" 
         },
    },
	['white_playboys'] = {
        label = 'White Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_white.png" 
         },
    },
	['white_playboys2'] = {
        label = 'White Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_white2.png" 
         },
    },
	['white_playboys3'] = {
        label = 'White Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_white3.png" 
         },
    },
	['white_playboys4'] = {
        label = 'White Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_white4.png" 
         },
    },
	['blue_playboys'] = {
        label = 'blue Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_blue.png" 
         },
    },
	['blue_playboys2'] = {
        label = 'blue Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_blue2.png" 
         },
    },
	['blue_playboys3'] = {
        label = 'blue Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_blue3.png" 
         },
    },
	['blue_playboys4'] = {
        label = 'blue Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_blue4.png" 
         },
    },
	['red_playboys'] = {
        label = 'red Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_red.png" 
         },
    },
	['red_playboys2'] = {
        label = 'red Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_red2.png" 
         },
    },
	['red_playboys3'] = {
        label = 'red Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_red3.png" 
         },
    },
	['red_playboys4'] = {
        label = 'red Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_red4.png" 
         },
    },
	['orange_playboys'] = {
        label = 'orange Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_orange.png" 
         },
    },
	['orange_playboys2'] = {
        label = 'orange Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_orange2.png" 
         },
    },
	['orange_playboys3'] = {
        label = 'orange Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_orange3.png" 
         },
    },
	['orange_playboys4'] = {
        label = 'orange Fruit',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "playboy_orange4.png" 
         },
    },
	['white_aliens'] = {
        label = 'White aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_white.png" 
         },
    },
	['white_aliens2'] = {
        label = 'White aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_white2.png" 
         },
    },
	['white_aliens3'] = {
        label = 'White aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_white3.png" 
         },
    },
	['white_aliens4'] = {
        label = 'White aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_white4.png" 
         },
    },
	['blue_aliens'] = {
        label = 'blue aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_blue.png" 
         },
    },
	['blue_aliens2'] = {
        label = 'blue aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_blue2.png" 
         },
    },
	['blue_aliens3'] = {
        label = 'blue aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_blue3.png" 
         },
    },
	['blue_aliens4'] = {
        label = 'blue aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_blue4.png" 
         },
    },
	['red_aliens'] = {
        label = 'red aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_red.png" 
         },
    },
	['red_aliens2'] = {
        label = 'red aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_red2.png" 
         },
    },
	['red_aliens3'] = {
        label = 'red aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_red3.png" 
         },
    },
	['red_aliens4'] = {
        label = 'red aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_red4.png" 
         },
    },
	['orange_aliens'] = {
        label = 'orange aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_orange.png" 
         },
    },
	['orange_aliens2'] = {
        label = 'orange aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_orange2.png" 
         },
    },
	['orange_aliens3'] = {
        label = 'orange aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_orange3.png" 
         },
    },
	['orange_aliens4'] = {
        label = 'orange aliens',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "alien_orange4.png" 
         },
    },
	['white_pl'] = {
        label = 'White pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_white.png" 
         },
    },
	['white_pl2'] = {
        label = 'White pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_white2.png" 
         },
    },
	['white_pl3'] = {
        label = 'White pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_white3.png" 
         },
    },
	['white_pl4'] = {
        label = 'White pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_white4.png" 
         },
    },
	['blue_pl'] = {
        label = 'blue pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_blue.png" 
         },
    },
	['blue_pl2'] = {
        label = 'blue pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_blue2.png" 
         },
    },
	['blue_pl3'] = {
        label = 'blue pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_blue3.png" 
         },
    },
	['blue_pl4'] = {
        label = 'blue pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_blue4.png" 
         },
    },
	['red_pl'] = {
        label = 'red pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_red.png" 
         },
    },
	['red_pl2'] = {
        label = 'red pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_red2.png" 
         },
    },
	['red_pl3'] = {
        label = 'red pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_red3.png" 
         },
    },
	['red_pl4'] = {
        label = 'red pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_red4.png" 
         },
    },
	['orange_pl'] = {
        label = 'orange pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_orange.png" 
         },
    },
	['orange_pl2'] = {
        label = 'orange pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_orange2.png" 
         },
    },
	['orange_pl3'] = {
        label = 'orange pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_orange3.png" 
         },
    },
	['orange_pl4'] = {
        label = 'orange pl',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "PL_orange4.png" 
         },
    },
	['white_trolls'] = {
        label = 'White trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_white.png" 
         },
    },
	['white_trolls2'] = {
        label = 'White trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_white2.png" 
         },
    },
	['white_trolls3'] = {
        label = 'White trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_white3.png" 
         },
    },
	['white_trolls4'] = {
        label = 'White trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_white4.png" 
         },
    },
	['blue_trolls'] = {
        label = 'blue trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_blue.png" 
         },
    },
	['blue_trolls2'] = {
        label = 'blue trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_blue2.png" 
         },
    },
	['blue_trolls3'] = {
        label = 'blue trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_blue3.png" 
         },
    },
	['blue_trolls4'] = {
        label = 'blue trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_blue4.png" 
         },
    },
	['red_trolls'] = {
        label = 'red trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_red.png" 
         },
    },
	['red_trolls2'] = {
        label = 'red trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_red2.png" 
         },
    },
	['red_trolls3'] = {
        label = 'red trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_red3.png" 
         },
    },
	['red_trolls4'] = {
        label = 'red trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_red4.png" 
         },
    },
	['orange_trolls'] = {
        label = 'orange trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_orange.png" 
         },
    },
	['orange_trolls2'] = {
        label = 'orange trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_orange2.png" 
         },
    },
	['orange_trolls3'] = {
        label = 'orange trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_orange3.png" 
         },
    },
	['orange_trolls4'] = {
        label = 'orange trolls',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "troll_orange4.png" 
         },
    },
	['white_cats'] = {
        label = 'White cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_white.png" 
         },
    },
	['white_cats2'] = {
        label = 'White cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_white2.png" 
         },
    },
	['white_cats3'] = {
        label = 'White cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_white3.png" 
         },
    },
	['white_cats4'] = {
        label = 'White cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_white4.png" 
         },
    },
	['blue_cats'] = {
        label = 'blue cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_blue.png" 
         },
    },
	['blue_cats2'] = {
        label = 'blue cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_blue2.png" 
         },
    },
	['blue_cats3'] = {
        label = 'blue cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_blue3.png" 
         },
    },
	['blue_cats4'] = {
        label = 'blue cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_blue4.png" 
         },
    },
	['red_cats'] = {
        label = 'red cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_red.png" 
         },
    },
	['red_cats2'] = {
        label = 'red cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_red2.png" 
         },
    },
	['red_cats3'] = {
        label = 'red cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_red3.png" 
         },
    },
	['red_cats4'] = {
        label = 'red cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_red4.png" 
         },
    },
	['orange_cats'] = {
        label = 'orange cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_orange.png" 
         },
    },
	['orange_cats2'] = {
        label = 'orange cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_orange2.png" 
         },
    },
	['orange_cats3'] = {
        label = 'orange cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_orange3.png" 
         },
    },
	['orange_cats4'] = {
        label = 'orange cats',
        weight = 100,
        stack = true,
        close = true,
        client = { 
           image = "kitty_orange4.png" 
         },
    },
    ["blue_uninflated_balloon"] = { 
    label = 'Blue Uninflated Balloon', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'blue_uninflated_balloon.png' } 
},
["cracker"] = { 
    label = 'Cracker', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'cracker.png' } 
},
["green_uninflated_balloon"] = { 
    label = 'Green Uninflated Balloon', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'green_uninflated_balloon.png' } 
},
["orange_uninflated_balloon"] = { 
    label = 'Orange Uninflated Balloon', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'orange_uninflated_balloon.png' } 
},
["purple_uninflated_balloon"] = { 
    label = 'Purple Uninflated Balloon', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'purple_uninflated_balloon.png' } 
},
["red_uninflated_balloon"] = { 
    label = 'Red Uninflated Balloon', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'red_uninflated_balloon.png' } 
},
["whipped_cream_cannister"] = { 
    label = 'Whipped Cream Cannister', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'whipped_cream_cannister.png' } 
},
["white_uninflated_balloon"] = { 
    label = 'White Uninflated Balloon', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'white_uninflated_balloon.png' } 
},
["yellow_uninflated_balloon"] = { 
    label = 'Yellow Uninflated Balloon', 
    description = "", 
    weight = 100, 
    stack = true, 
    close = true, 
    client = { image = 'yellow_uninflated_balloon.png' } 
},
}
