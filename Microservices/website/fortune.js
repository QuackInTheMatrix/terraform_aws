document.addEventListener("DOMContentLoaded", () => {
    fetch('https://api.ivandeveric.site/api/db/fortunes')
        .then(response => response.json())
        .then(data => {
            document.getElementById("fortune").textContent=data.message
        })
        .catch(error => {
            console.error('Error fetching data:', error);
    });
    document.getElementById("subscribe-button").addEventListener("click", () => {
        function validateEmail(email) {
            return String(email)
                .toLowerCase()
                .match(
                /^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|.(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
                );
        }
        const emailInput = document.getElementById("email-input").value;
        if (!validateEmail(emailInput)) {
            document.getElementById("confirm-subscribe").textContent=`Email "${emailInput}" is invalid!`;
            return;
        }else{
            document.getElementById("confirm-subscribe").textContent="";
        }
        const dataToAdd = { "message": emailInput };
        fetch('https://api.ivandeveric.site/TODO_ENDPOINT', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(dataToAdd)
        })
        .then(response => response.json())
        .then(data => {
            document.getElementById("confirm-subscribe").textContent="Success! Please check your email and confirm.";
        })
        .catch(error => {
            document.getElementById("confirm-subscribe").textContent="Failure!";
            console.error('Error updating data:', error);
        });
    });
});
