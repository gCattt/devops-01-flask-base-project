var navigationLinks = document.querySelectorAll('nav > ul > li > a');
var sections = document.getElementsByTagName('section');

var sectionIdTonavigationLink = {};
for (var i = sections.length-1; i >= 0; i--) {
	var id = sections[i].id;
	sectionIdTonavigationLink[id] = document.querySelectorAll('nav > ul > li > a[href=\\#' + id + ']') || null;
}
console.log(sectionIdTonavigationLink);

function throttle(fn, interval) {
	var lastCall, timeoutId;
	return function () {
		var now = new Date().getTime();
		if (lastCall && now < (lastCall + interval) ) {
			clearTimeout(timeoutId);
			timeoutId = setTimeout(function () {
				lastCall = now;
				fn.call();
			}, interval - (now - lastCall) );
		} else {
			lastCall = now;
			fn.call();
		}
	};
}

function getOffset( el ) {
	var _x = 0;
	var _y = 0;
	while( el && !isNaN( el.offsetLeft ) && !isNaN( el.offsetTop ) ) {
		_x += el.offsetLeft - el.scrollLeft;
		_y += el.offsetTop - el.scrollTop;
		el = el.offsetParent;
	}
	return { top: _y, left: _x };
}

function highlightNavigation() {
	var scrollPosition = window.pageYOffset || document.documentElement.scrollTop;

	for (var i = sections.length-1; i >= 0; i--) {
		var currentSection = sections[i];
		var sectionTop = getOffset(currentSection).top;

		if (scrollPosition >= sectionTop - window.innerHeight / 2 ) {
			var id = currentSection.id;
			var navigationLink = sectionIdTonavigationLink[id];
			if (typeof navigationLink[0] !== 'undefined') {
				if (!navigationLink[0].classList.contains('active')) {
					for (i = 0; i < navigationLinks.length; i++) {
						navigationLinks[i].className = navigationLinks[i].className.replace(/active/, '');
					}
					navigationLink[0].className += (' active');
				}
			} else {
					for (i = 0; i < navigationLinks.length; i++) {
						navigationLinks[i].className = navigationLinks[i].className.replace(/active/, '');
					}
			}	
			return false;
		}
	}
}

window.addEventListener('scroll',throttle(highlightNavigation,150));



var titlebar = document.getElementById('titlebar');
var main = document.getElementById('main');
var body = document.getElementsByTagName('body');
var menuicon = document.getElementById('icon-menu');
var closeicon = document.getElementById('icon-close');


titlebar.addEventListener('click', function handleClick(event) {
	if (!body[0].classList.contains('header-visible')){
		body[0].className += (' header-visible');
		menuicon.style.display = 'none';
		closeicon.style.display = 'block';
	} else {
		body[0].className = body[0].className.replace(/ header-visible/, '');
		closeicon.style.display = 'none';
		menuicon.style.display = 'block';
	}
});