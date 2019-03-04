import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

(async() => {

    let result = null;

    let STATUS_CODES = [{
        label: 'STATUS_CODE_UNKNOWN',
        code: 0
    }, {
        label: 'STATUS_CODE_ON_TIME',
        code: 10
    }, {
        label: 'STATUS_CODE_LATE_AIRLINE',
        code: 20
    }, {
        label: 'STATUS_CODE_LATE_WEATHER',
        code: 30
    }, {
        label: 'STATUS_CODE_LATE_TECHNICAL',
        code: 40
    }, {
        label: 'STATUS_CODE_LATE_OTHER',
        code: 50
    }];

    let contract = new Contract('localhost', () => {
        contract.isOperational((error, result) => {
            contract.flights.forEach(flight => {
                displayList(flight, DOM.flightSelector)
            });
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });


        contract.flightSuretyData.events.amountWithdrawn({
            fromBlock: 'latest'
        }, function (error, result) {
            if (error) {
                console.log(error)
            } else {
                display('Withdraw Amount', 'Withdraw amount to wallet', [ { label: 'Amount withdrawn', error: error, value: `Amount ${result.returnValues.amount} withdrawn to ${result.returnValues.senderAddress} at ${new Date()}`} ]);
            }
        });

        contract.flightSuretyData.events.airlineFunded({
            fromBlock: 'latest'
        }, function (error, result) {
            if (error) {
                console.log(error)
            } else {
                display('Airline Funded', 'Airline funded by the Airline', [ { label: 'Airline Funded', error: error, value: `Airline ${result.returnValues.airlineAddress} got funded`} ]);
            }
        });

        contract.flightSuretyData.events.insuranceClaimed({
            fromBlock: 'latest'
        }, function (error, result) {
            if (error) {
                console.log(error)
            } else {
                display('Claim Insurance', 'Insurance claimed by passenger', [ { label: 'Insurance Claimed', error: error, value: `Insurance claimed by ${result.returnValues.passenger}. An amount of ${result.returnValues.amountCreditedToPassenger} WEI has been added to his wallet for ${result.returnValues.flight} at ${new Date(result.returnValues.timestamp * 1000)}`} ]);
            }
        });


        DOM.elid('submit-oracle').addEventListener('click', () => {
            const flight = DOM.elid('flight-number').value;
            DOM.elid('flight-number').value = '';

            contract.fetchFlightStatus(flight, (error, result) => {
                let selectFlight = DOM.elid('selectFlight');
                addFlightSection(result, selectFlight);
                display('Oracles', 'Trigger oracles', [ {
                    label: 'Fetch Flight Status -->',
                    error, 
                    value: `Flight ${result.flight} scheduled at ${new Date(result.timestamp * 1000)}`
                } ]);
            });
        });

        DOM.elid('buyInsurance').addEventListener('click', () => {
            const selectedFlightElement = document.getElementById("selectFlight");
            let selectedFlightValue = selectedFlightElement.options[selectedFlightElement.selectedIndex].value;
            let insuranceAmount = DOM.elid('insuranceAmount').value;

            if (!insuranceAmount) {
                alert('You should enter amount of insurance');
                return;
            }
            
            if(selectedFlightValue === 'Select') {
                alert('You should select your flight and time of departure');
            } else {
                DOM.elid('insuranceAmount').value = '';
                selectedFlightValue = JSON.parse(selectedFlightValue);

                contract.buyInsurance(selectedFlightValue, insuranceAmount, (error, result) => {
                    if (error) {
                        alert(error);
                    }
                    let value = DOM.div({className: 'col-sm-8 field-value'});
                    value.innerHTML = [
                        '<div>' + `Passenger --> ${result.passenger}` + '</div>',
                        '<div>' + `Amount --> ${result.insuranceAmount} ETH` + '</div>',
                        '<div>' + `Flight --> ${result.flight}` + '</div>',
                        '<div>' + `Airline --> ${result.airline}` + '</div>',
                        '<div>' + `Schedule --> ${new Date(result.timestamp * 1000)}` + '</div>',
                    ].join('');
                    display('Buy Insurance', 'Insurance purchased by the passenger', [{
                        label: 'Insurance Purchased -->',
                        error,
                        value
                    }], true);
                });
            }
        });

        DOM.elid('withdrawFund').addEventListener('click', () => {
            const address = DOM.elid('withdrawalAddress').value;

            contract.withdrawAmount(address, (error, result) => {
                error && alert(error);
            });
        });
    });
})();

function addFlightSection(flight, selectComponent) {
    const option = document.createElement('option');
    option.text =  `Flight ${flight.flight} scheduled at ${new Date(flight.timestamp)}`;
    option.value = JSON.stringify(flight);

    selectComponent.add(option);
}

function display(title, description, results, isDomNode) {
    let displayDiv = DOM.elid('display-wrapper');
    let section = DOM.section();

    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));

    results.map((result) => {
        let row = section.appendChild(DOM.div({ className:'row' }));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        if (isDomNode && !result.error) {
            row.appendChild(result.value);
        } else {
            row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));

        }
        section.appendChild(row);
    });
    displayDiv.append(section);
}