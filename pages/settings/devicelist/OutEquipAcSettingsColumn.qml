/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	Extra controls for an OutEquipPro rooftop AC bridged onto a
	com.victronenergy.switch service by the VeOutEquipAC driver.

	Power on/off is the device's regular SwitchableOutput, shown here as a
	direct toggle rather than the generic single-output sub-page PageSwitch.qml
	would otherwise     link to (unnecessary ceremony for a plain on/off relay --
	see the toggle below). The driver additionally publishes mode/fan speed/
	setpoint/swing/temperature/voltage under a non-standard /Ac/* namespace,
	which the stock switch page has no concept of -- this column adds native
	controls for those paths too.

	Only renders when the device actually publishes /Ac/Mode, so it has no
	effect on any other switch/relay device.
*/
SettingsColumn {
	id: root

	required property string serviceUid

	readonly property string _acPrefix: root.serviceUid + "/Ac/"

	visible: modeItem.valid
	preferredVisible: modeItem.valid
	width: parent?.width ?? 0

	VeQuickItem {
		id: modeItem
		uid: root._acPrefix + "Mode"
	}

	SectionHeader {
		text: "Air conditioner"
	}

	// The device's SwitchableOutput already provides this control, but the
	// generic single-output delegate on this page (see PageSwitch.qml)
	// always links to a sub-page -- appropriate for output types that
	// genuinely need one (color wheels, sliders, dropdowns, etc.), but
	// unnecessary ceremony for this AC's plain on/off toggle. PageSwitch.qml
	// suppresses that generic sub-page entry for this device in favour of
	// this direct toggle.
	ListSwitch {
		text: "Power"
		dataItem.uid: root.serviceUid + "/SwitchableOutput/output_1/State"
	}

	ListRadioButtonGroup {
		text: "Mode"
		dataItem.uid: root._acPrefix + "Mode"
		optionModel: [
			{ display: "Cool", value: 1 },
			{ display: "Heat", value: 2 },
			{ display: "Fan", value: 3 },
			{ display: "Eco Cool", value: 4 },
			{ display: "Sleep Cool", value: 5 },
			{ display: "Turbo Cool", value: 6 },
			{ display: "Wet/Dehumidify", value: 7 },
		]
	}

	ListSlider {
		text: "Fan speed"
		dataItem.uid: root._acPrefix + "FanSpeed"
		from: 1
		to: 5
		stepSize: 1
	}

	ListSpinBox {
		// The setpoint register carries a plain integer in whole Fahrenheit
		// degrees, so the 63-86 range below is in °F (~17-30 °C).
		text: "Setpoint"
		dataItem.uid: root._acPrefix + "SetpointTemperature"
		from: 63
		to: 86
		stepSize: 1
		decimals: 0
		suffix: Units.defaultUnitString(VenusOS.Units_Temperature_Fahrenheit)
	}

	ListSwitch {
		text: "Swing"
		dataItem.uid: root._acPrefix + "Swing"
	}

	ListTemperature {
		text: "Intake temperature"
		dataItem.uid: root._acPrefix + "IntakeTemperature"
		dataItem.sourceUnit: Units.unitToVeUnit(VenusOS.Units_Temperature_Fahrenheit)
		preferredVisible: dataItem.valid
		decimals: 0
	}

	ListTemperature {
		text: "Outlet temperature"
		dataItem.uid: root._acPrefix + "OutletTemperature"
		dataItem.sourceUnit: Units.unitToVeUnit(VenusOS.Units_Temperature_Fahrenheit)
		preferredVisible: dataItem.valid
		decimals: 0
	}

	ListQuantity {
		text: "Supply voltage"
		dataItem.uid: root._acPrefix + "SupplyVoltage"
		preferredVisible: dataItem.valid
		unit: VenusOS.Units_Volt_DC
		decimals: 1
	}
}
