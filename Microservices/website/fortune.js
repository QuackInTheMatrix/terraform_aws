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
                .match(/^[\w\-\.]+@([\w-]+\.)+[\w-]{2,}$/);
        }
        // VARS
        let subscribe_txt = document.getElementById("confirm-subscribe");
        const emailInput = document.getElementById("email-input").value;
        if (!validateEmail(emailInput)) {
            subscribe_txt.textContent=`Email "${emailInput}" is invalid!`;
            return;
        }else{
            subscribe_txt.textContent="";
        }
        const dataToAdd = { "email": emailInput };
        fetch('https://api.ivandeveric.site/fortune/subscribe', {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(dataToAdd)
        })
        .then(response => response.json())
        .then(data => {
            subscribe_txt.textContent=data.message;
            let email_server = document.createElement("a");
            email_server.href = `https://${emailInput.split("@")[1]}`;
            email_server.innerHTML = "Click this link to go to your email.";
            subscribe_txt.parentNode.appendChild(email_server);
        })
        .catch(error => {
            subscribe_txt.textContent=error.message;
            console.error('Error subscribing:', error);
        });
    });
});
