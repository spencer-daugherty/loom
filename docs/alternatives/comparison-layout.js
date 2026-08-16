(function () {
  "use strict";

  document.querySelectorAll(".comparison-table-card table, .fit-table").forEach(function (table) {
    var headers = Array.from(table.querySelectorAll("thead th")).map(function (header) {
      return header.textContent.trim();
    });
    if (!headers.length) return;

    if (!table.querySelector("caption")) {
      var caption = document.createElement("caption");
      var disclosure = table.closest(".life-disclosure");
      var section = table.closest("section") || table.closest(".article-body");
      var heading = (disclosure && disclosure.querySelector("h2")) ||
        (section && section.querySelector("h2"));
      caption.textContent = (heading ? heading.textContent.trim() : "Feature comparison") +
        ". Each criterion is presented as a separate card on smaller screens.";
      table.prepend(caption);
    }

    table.querySelectorAll("tbody tr").forEach(function (row) {
      Array.from(row.children).forEach(function (cell, index) {
        if (index > 0 && headers[index]) cell.dataset.columnLabel = headers[index];
      });
    });

    table.classList.add("comparison-layout-ready");
    var wrapper = table.closest(".table-wrap, .fit-table-wrap");
    if (wrapper) wrapper.classList.add("comparison-layout-ready");
  });
})();
