import fitz  # PyMuPDF
import os

def extract_half_page_text(pdf_path, output_path):
    """
    Extracts text from a PDF where each page contains two separate columns
    of text (left and right), processing the left column completely, then the right.

    Args:
        pdf_path (str): The path to the input PDF file.
        output_path (str): The path to save the extracted text file.
    """
    doc = fitz.open(pdf_path)
    full_text = []

    print(f"Processing {len(doc)} pages from '{os.path.basename(pdf_path)}'...")

    for page_num in range(len(doc)):
        page = doc.load_page(page_num)
        
        # Get page dimensions
        page_width = page.rect.width
        page_height = page.rect.height
        
        # Define the rectangle for the left half of the page
        # It spans from the left edge (0) to the horizontal center (page_width / 2)
        left_rect = fitz.Rect(0, 0, page_width / 2, page_height)
        
        # Define the rectangle for the right half of the page
        # It spans from the horizontal center (page_width / 2) to the right edge
        right_rect = fitz.Rect(page_width / 2, 0, page_width, page_height)
        
        # Extract text from each half, sorted by vertical position
        left_text = page.get_text("text", clip=left_rect, sort=True)
        right_text = page.get_text("text", clip=right_rect, sort=True)
        
        # Append the extracted text to the list
        if left_text:
            full_text.append(left_text)
        if right_text:
            full_text.append(right_text)
            
        print(f"  - Page {page_num + 1}: Extracted {len(left_text.splitlines())} lines from left, {len(right_text.splitlines())} lines from right.")

    # Write the combined text to the output file
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(full_text))
        
    print(f"\nExtraction complete. Text saved to '{os.path.basename(output_path)}'.")

if __name__ == "__main__":
    # Define file paths relative to the script's location
    # Assumes the script is in 'py/' and data is in 'py/data/'
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_pdf = os.path.join(script_dir, 'data', 'joukaku.pdf')
    output_txt = os.path.join(script_dir, 'data', 'joukaku_extracted.txt')
    
    # Ensure the input file exists
    if not os.path.exists(input_pdf):
        print(f"Error: Input file not found at '{input_pdf}'")
    else:
        extract_half_page_text(input_pdf, output_txt)
