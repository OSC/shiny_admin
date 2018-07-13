document.addEventListener('DOMContentLoaded',function() {
    // Install handler
    const SELECTOR = 'input[type="radio"][name="mapping[dataset]"]';
    let buttons = document.querySelectorAll(SELECTOR);
    for(let button of buttons) {
        button.onchange=changeEventHandler;
    }
},false);

function changeEventHandler(event) {
    // You can use “this” to refer to the selected element.
    const SELECTOR = 'input[name="mapping[dataset_non_std_location_value]"]';
    let element = document.querySelector(SELECTOR);
    let disabled = true;

    if(this.value === 'dataset_non_std_location' && this.checked) {
        disabled = false;
    }

    element.disabled = disabled;
}