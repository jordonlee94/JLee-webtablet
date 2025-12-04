const resName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "Jlee-DarkwebTablet";
const tabs = document.querySelectorAll(".tabs button");
const toastEl = document.getElementById("toast");

let cfgDrugs = [];
let cfgGuns = [];

function showToast(msg) {
    if (!toastEl) return;
    toastEl.textContent = msg;
    toastEl.classList.remove("hidden");
    setTimeout(() => toastEl.classList.add("hidden"), 2000);
}

function categoryFromTab(tab) {
    if (tab === "items") return "item";
    if (tab === "cars")  return "vehicle";
    if (tab === "drugs") return "drug";
    if (tab === "guns")  return "gun";
    return "item";
}

function itemImage(name) {
    return `nui://qb-inventory/html/images/${name}.png`;
}

function switchTab(tab) {
    document.querySelectorAll(".tab").forEach(t => t.classList.add("hidden"));
    const el = document.getElementById(`tab-${tab}`);
    if (el) el.classList.remove("hidden");

    tabs.forEach(b => b.classList.remove("active"));
    const btn = document.querySelector(`[data-tab="${tab}"]`);
    if (btn) btn.classList.add("active");

    loadListings(tab);

    if (tab === "items" || tab === "drugs" || tab === "guns") {
        refreshInventoryDropdowns();
    }
    if (tab === "cars") {
        loadOwnedCars();
    }
}

tabs.forEach(btn => {
    btn.addEventListener("click", () => switchTab(btn.dataset.tab));
});

function loadListings(tab) {
    const cat = categoryFromTab(tab);
    $.post(`https://${resName}/loadListings`, JSON.stringify({ category: cat }), function(list) {
        renderListings(tab, list || []);
    });
}

function renderListings(tab, listings) {
    const containerId = { items: "items", cars: "cars", drugs: "drugs", guns: "guns" }[tab];
    const target = document.getElementById(containerId);
    if (!target) return;
    target.innerHTML = "";

    if (!listings.length) {
        target.innerHTML = "<div style='color:#777;font-size:12px;'>No listings.</div>";
        return;
    }

    listings.forEach(l => {
        const wrap = document.createElement("div");
        wrap.className = "listing";

        const left = document.createElement("div");
        left.className = "listing-left";

        const iconWrap = document.createElement("div");
        iconWrap.className = "item-icon-wrapper";

        const icon = document.createElement("img");
        icon.className = "item-icon";

        if (tab !== "cars") {
            icon.src = itemImage(l.item);
            icon.onerror = function () { this.style.display = "none"; };
        } else {
            icon.style.display = "none";
        }

        const info = document.createElement("div");
        info.className = "item-info";
        info.innerHTML = `
            <div class="item-info-main">${l.label} <span>x${l.amount}</span></div>
            <div class="item-info-price">$${l.price}</div>
            <div class="item-info-meta">ID: ${l.id}</div>
        `;

        iconWrap.appendChild(icon);
        left.appendChild(iconWrap);
        left.appendChild(info);

        const right = document.createElement("div");

        // Buyer selects payment method
        const paySel = document.createElement("select");
        ["cash","bank","marked_bills"].forEach(p => {
            const o = document.createElement("option");
            o.value = p;
            o.textContent = p.toUpperCase().replace("_"," ");
            paySel.appendChild(o);
        });

        const bBuy = document.createElement("button");
        bBuy.className = "btn buy";
        bBuy.textContent = "BUY";
        bBuy.onclick = () => {
            $.post(`https://${resName}/buyListing`, JSON.stringify({
                id: l.id,
                payment_type: paySel.value
            }), res => {
                showToast(res.msg || (res.success ? "Purchased" : "Error"));
                loadListings(tab);
                if (tab === "cars") loadOwnedCars();
                setTimeout(refreshInventoryDropdowns, 200); // ensure dropdown reflects new inventory
            });
        };

        const bCancel = document.createElement("button");
        bCancel.className = "btn cancel";
        bCancel.textContent = "CANCEL";
        bCancel.onclick = () => {
            $.post(`https://${resName}/cancelListing`, JSON.stringify({ id: l.id }), res => {
                showToast(res.msg || (res.success ? "Listing cancelled" : "Error"));
                loadListings(tab);
                if (tab === "cars") loadOwnedCars();
                setTimeout(refreshInventoryDropdowns, 200);
            });
        };

        right.appendChild(paySel);
        right.appendChild(bBuy);
        right.appendChild(bCancel);

        wrap.appendChild(left);
        wrap.appendChild(right);
        target.appendChild(wrap);
    });
}

// Owned cars
function loadOwnedCars() {
    $.post(`https://${resName}/getOwnedCars`, JSON.stringify({}), cars => {
        const sel = document.getElementById("car-select");
        if (!sel) return;
        sel.innerHTML = "";
        cars = cars || [];
        if (!cars.length) {
            const opt = document.createElement("option");
            opt.value = "";
            opt.textContent = "No vehicles found";
            sel.appendChild(opt);
            return;
        }
        cars.forEach(c => {
            const opt = document.createElement("option");
            opt.value = c.plate;
            opt.textContent = `${c.plate} (${c.vehicle})`;
            sel.appendChild(opt);
        });
    });
}

// Inventory dropdowns
function refreshInventoryDropdowns() {
    $.post(`https://${resName}/getInventory`, JSON.stringify({}), response => {
        let items = [];

        if (Array.isArray(response)) {
            items = response;
        } else if (response && typeof response === "object") {
            items = Object.values(response);
        } else {
            items = [];
        }

        const itemSel = document.getElementById("item-select");
        const drugSel = document.getElementById("drug-select");
        const gunSel  = document.getElementById("gun-select");

        if (itemSel) itemSel.innerHTML = "<option value=''>Select item</option>";
        if (drugSel) drugSel.innerHTML = "<option value=''>Select drug</option>";
        if (gunSel)  gunSel.innerHTML  = "<option value=''>Select gun</option>";

        items.forEach(it => {
            if (!it || !it.name || !it.amount || it.amount <= 0) return;

            const name = it.name.toLowerCase();
            const opt = document.createElement("option");
            opt.value = it.name; // keep original name for server
            opt.textContent = `${it.label} (x${it.amount})`;

            if (cfgDrugs.includes(name) && drugSel) {
                drugSel.appendChild(opt);
            } else if (cfgGuns.includes(name) && gunSel) {
                gunSel.appendChild(opt);
            } else if (itemSel) {
                itemSel.appendChild(opt);
            }
        });
    });
}

// Close button
document.getElementById("close").onclick = () => {
    $.post(`https://${resName}/close`, JSON.stringify({}));
};

// List item
document.getElementById("list-item").onclick = () => {
    $.post(`https://${resName}/createListing`, JSON.stringify({
        category: "item",
        item: document.getElementById("item-select").value,
        amount: Number(document.getElementById("item-amount").value) || 1,
        price: Number(document.getElementById("item-price").value) || 0
    }), res => {
        showToast(res.msg || (res.success ? "Item listed" : "Error"));
        loadListings("items");
        setTimeout(refreshInventoryDropdowns, 200);
    });
};

// List car
document.getElementById("list-car").onclick = () => {
    const plate = document.getElementById("car-select").value;
    $.post(`https://${resName}/createListing`, JSON.stringify({
        category: "vehicle",
        plate: plate,
        price: Number(document.getElementById("car-price").value) || 0
    }), res => {
        showToast(res.msg || (res.success ? "Car listed" : "Error"));
        loadListings("cars");
        loadOwnedCars();
    });
};

// List drug
document.getElementById("list-drug").onclick = () => {
    $.post(`https://${resName}/createListing`, JSON.stringify({
        category: "drug",
        item: document.getElementById("drug-select").value,
        amount: Number(document.getElementById("drug-amount").value) || 1,
        price: Number(document.getElementById("drug-price").value) || 0
    }), res => {
        showToast(res.msg || (res.success ? "Drug listed" : "Error"));
        loadListings("drugs");
        setTimeout(refreshInventoryDropdowns, 200);
    });
};

// List gun
document.getElementById("list-gun").onclick = () => {
    $.post(`https://${resName}/createListing`, JSON.stringify({
        category: "gun",
        item: document.getElementById("gun-select").value,
        amount: 1,
        price: Number(document.getElementById("gun-price").value) || 0
    }), res => {
        showToast(res.msg || (res.success ? "Gun listed" : "Error"));
        loadListings("guns");
        setTimeout(refreshInventoryDropdowns, 200);
    });
};

// NUI messages
window.addEventListener("message", ev => {
    if (ev.data.action === "setConfig") {
        // normalize to lowercase for matching
        cfgDrugs = (ev.data.drugs || []).map(d => String(d).toLowerCase());
        cfgGuns  = (ev.data.guns  || []).map(g => String(g).toLowerCase());
    }
    if (ev.data.action === "open") {
        document.getElementById("app").classList.remove("hidden");
        switchTab("items");
        refreshInventoryDropdowns();
        loadOwnedCars();
    }
    if (ev.data.action === "close") {
        document.getElementById("app").classList.add("hidden");
    }
});
