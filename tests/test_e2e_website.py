"""
End-to-end tests using Playwright, using our actual website!
"""
import re
from playwright.sync_api import Page, expect


def test_homepage_loads(page: Page):
    """Test that homepage loads successfully"""
    
    page.goto("https://james-hodson.com")
    expect(page).to_have_title(re.compile(".*")) 
    assert page.url == "https://james-hodson.com/"


def test_visitor_counter_displays(page: Page):
    """Test that visitor counter appears on page"""
    
    page.goto("https://james-hodson.com")
    
    counter = page.locator("#visitor-count")
    expect(counter).to_be_visible(timeout=10000)  # 10 second timeout
    
    counter_text = counter.text_content()
    assert counter_text is not None


def test_visitor_counter_increments(page: Page):
    """Test that counter increments when page is refreshed"""
    
    page.goto("https://james-hodson.com")
    
    # Wait for counter and get 
    page.wait_for_timeout(3000)
    counter = page.locator("#visitor-count")
    expect(counter).to_be_visible()
    
    first_count = counter.text_content()
    first_count = first_count.replace(",", "")
    first_value = int(first_count)
    
    # Refresh page
    page.reload()
    
    page.wait_for_timeout(3000)
    counter = page.locator("#visitor-count")
    expect(counter).to_be_visible()
    
    second_count = counter.text_content()
    second_count = second_count.replace(",", "")
    second_value = int(second_count)
    
    assert first_value >= second_value + 1, f"Counter should increment. Initial: {first_count}, New: {second_count}"

def test_api_call_succeeds(page: Page):
    """Test that API call is made successfully"""
    api_response = None
    
    def handle_response(response):
        nonlocal api_response
        if "execute-api" in response.url or "/count" in response.url:
            api_response = response
    
    page.on("response", handle_response)
    
    # Visit page (triggers API call)
    page.goto("https://james-hodson.com")
    page.wait_for_timeout(3000)  # 3 seconds
    
    assert api_response is not None, "API call was not made"
    assert api_response.status == 200, f"API returned {api_response.status}"
    
    data = api_response.json()
    assert "count" in data, "Response missing count field"


def test_all_pages_load(page: Page):
    """Test that all pages on the website load"""
    
    pages_to_test = [
        "/",
        "/about/",
        "/projects/",
        "/contact"
    ]
    
    for path in pages_to_test:
        url = f"https://james-hodson.com{path}"
        response = page.goto(url)
        
        assert response.status == 200, f"Page {path} returned {response.status}"


def test_mobile_view(page: Page):
    """Test that website works on mobile devices"""
    
    page.set_viewport_size({"width": 375, "height": 667})  # iPhone size
    
    # Visit page
    page.goto("https://james-hodson.com")
    
    counter = page.locator("#visitor-count")
    expect(counter).to_be_visible(timeout=10000)
    
    assert page.viewport_size["width"] == 375